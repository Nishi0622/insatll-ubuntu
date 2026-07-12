#!/usr/bin/env bash
set -euo pipefail

APP_USER="${APP_USER:-konomi}"
APP_HOME="${APP_HOME:-/opt/konomi}"
APP_DIR="${APP_DIR:-/opt/konomi/app}"
DATA_ROOT="${DATA_ROOT:-/var/lib/konomi/data}"
MEDIA_ROOT="${MEDIA_ROOT:-/var/lib/konomi/media}"
REPO_URL="${REPO_URL:-git@github.com:Nishi0622/konomi.git}"
SERVICE_NAME="${SERVICE_NAME:-konomi}"
USER_PORT="${USER_PORT:-3000}"
ADMIN_PORT="${ADMIN_PORT:-3001}"
ADMIN_DISABLED="${ADMIN_DISABLED:-false}"
KEY_PATH="${KEY_PATH:-${APP_HOME}/.ssh/konomi_deploy_key}"

need_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "このスクリプトは root で実行してください: sudo bash install-ubuntu.sh"
    exit 1
  fi
}

confirm_install() {
  cat <<EOF
Konomi Ubuntu インストーラーを実行します。

実行内容:
- apt で必要パッケージをインストール
- Node.js 22 がない場合は導入
- ${APP_USER} ユーザーと保存先ディレクトリを作成
- GitHub Deploy Key を作成して登録待ち
- ${APP_DIR} に Konomi を clone / 更新
- konomi.config.json を作成
- systemd サービスを作成
- 管理画面からの更新機能を有効化
- Konomi を起動

保存先:
- app: ${APP_DIR}
- data: ${DATA_ROOT}
- media: ${MEDIA_ROOT}

続行するには yes と入力してください。
EOF
  read -r -p "> " answer
  if [ "$answer" != "yes" ]; then
    echo "インストールを中止しました。"
    exit 0
  fi
}

as_app_user() {
  sudo -u "$APP_USER" "$@"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

node_major() {
  if ! command_exists node; then
    echo 0
    return
  fi
  node -p "Number(process.versions.node.split('.')[0])" 2>/dev/null || echo 0
}

install_packages() {
  apt update
  apt install -y git curl ca-certificates openssh-client

  if [ "$(node_major)" -lt 22 ]; then
    echo "Node.js 22 をインストールします。"
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt install -y nodejs
  fi

  echo "Node: $(node -v)"
}

create_user_and_dirs() {
  if ! id "$APP_USER" >/dev/null 2>&1; then
    useradd --system --home "$APP_HOME" --shell /usr/sbin/nologin "$APP_USER"
  fi

  mkdir -p "$APP_HOME" "$DATA_ROOT" "$MEDIA_ROOT" "$(dirname "$KEY_PATH")"
  chown -R "$APP_USER:$APP_USER" "$APP_HOME" "$(dirname "$DATA_ROOT")" "$(dirname "$MEDIA_ROOT")"
}

setup_deploy_key() {
  if [ ! -f "$KEY_PATH" ]; then
    as_app_user ssh-keygen -t ed25519 -C "konomi-production" -f "$KEY_PATH" -N ""
  fi

  cat > "${APP_HOME}/.ssh/config" <<EOF
Host github.com
  HostName github.com
  User git
  IdentityFile ${KEY_PATH}
  IdentitiesOnly yes
EOF

  chmod 700 "${APP_HOME}/.ssh"
  chmod 600 "$KEY_PATH" "${APP_HOME}/.ssh/config"
  chown -R "$APP_USER:$APP_USER" "${APP_HOME}/.ssh"

  echo
  echo "次の公開鍵を GitHub の Deploy keys に登録してください。"
  echo
  cat "${KEY_PATH}.pub"
  echo
  echo "GitHub: Nishi0622/konomi > Settings > Deploy keys > Add deploy key"
  echo "Allow write access はオフでOKです。"
  echo
  read -r -p "登録できたら Enter を押してください。" _

  echo "GitHub SSH 接続を確認します。"
  set +e
  as_app_user ssh -o StrictHostKeyChecking=accept-new -T git@github.com
  ssh_status=$?
  set -e

  if [ "$ssh_status" -ne 1 ]; then
    echo "GitHub SSH 接続確認に失敗しました。Deploy Key の登録と権限を確認してください。"
    exit 1
  fi
}

clone_or_update_repo() {
  if [ -d "$APP_DIR/.git" ]; then
    as_app_user git -C "$APP_DIR" remote set-url origin "$REPO_URL"
    as_app_user git -C "$APP_DIR" pull --ff-only origin main
    return
  fi

  if [ -e "$APP_DIR" ]; then
    backup="${APP_DIR}.manual.backup.$(date +%Y%m%d-%H%M%S)"
    echo "${APP_DIR} は Git リポジトリではないため、${backup} に退避します。"
    mv "$APP_DIR" "$backup"
  fi

  as_app_user git clone "$REPO_URL" "$APP_DIR"
}

write_config() {
  cat > "${APP_DIR}/konomi.config.json" <<EOF
{
  "env": "production",
  "port": ${USER_PORT},
  "adminPort": ${ADMIN_PORT},
  "dataRoot": "${DATA_ROOT}",
  "mediaRoot": "${MEDIA_ROOT}",
  "adminDisabled": ${ADMIN_DISABLED}
}
EOF
  chown "$APP_USER:$APP_USER" "${APP_DIR}/konomi.config.json"
  chmod 600 "${APP_DIR}/konomi.config.json"
}

write_service() {
  node_path="$(command -v node)"

  cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=Konomi community server
After=network.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_USER}
WorkingDirectory=${APP_DIR}
Environment=NODE_ENV=production
Environment=KONOMI_CONFIG=${APP_DIR}/konomi.config.json
ExecStart=${node_path} server.js
Restart=always
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ReadWritePaths=${APP_HOME} /var/lib/konomi

[Install]
WantedBy=multi-user.target
EOF
}

start_service() {
  as_app_user node --check "${APP_DIR}/server.js"
  systemctl daemon-reload
  systemctl enable --now "$SERVICE_NAME"
  systemctl status "$SERVICE_NAME" --no-pager
}

main() {
  need_root
  confirm_install
  install_packages
  create_user_and_dirs
  setup_deploy_key
  clone_or_update_repo
  write_config
  write_service
  APP_USER="$APP_USER" APP_DIR="$APP_DIR" SERVICE_NAME="$SERVICE_NAME" bash "${APP_DIR}/scripts/setup-admin-update.sh"
  start_service

  echo
  echo "Konomi の Ubuntu 本番セットアップが完了しました。"
  echo "ユーザー側: http://localhost:${USER_PORT}"
  echo "管理側: http://localhost:${ADMIN_PORT}"
}

main "$@"
