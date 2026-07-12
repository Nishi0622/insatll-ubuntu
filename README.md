# nnn Ubuntu Installer

nnn を Ubuntu 本番サーバへ入れるための公開インストーラーです。

このリポジトリに秘密情報は入れません。nnn 本体は private repository のままなので、インストール中に表示される Deploy Key を GitHub に登録しない限り clone はできません。

## 使い方

```bash
curl -fsSL https://raw.githubusercontent.com/Nishi0622/insatll-ubuntu/main/install-ubuntu.sh -o install-ubuntu.sh
sudo bash install-ubuntu.sh
```

実行前に内容確認が表示されます。続行する場合だけ `yes` と入力してください。

インストーラーは次の処理を行います。

- 必要パッケージのインストール
- Node.js 22 の導入
- `nnn` ユーザー作成
- Deploy Key の作成と登録待ち
- GitHub から Konomi 本体を clone
- `nnn.config.json` 作成
- 管理画面からの更新用 `konomi-update.service` 作成
- `systemd` サービス作成
- nnn の起動

## 管理画面から更新を有効化する

あとから有効化する場合は、Konomi 本体側で次を実行します。

```bash
cd /opt/konomi/app
sudo bash scripts/setup-admin-update.sh
sudo systemctl restart konomi
```

## 注意

- GitHub の Deploy Key は `Allow write access` をオフにしてください。
- 管理画面ポート `3001` は Cloudflare Tunnel に公開しない運用を推奨します。
- DB、画像、`nnn.config.json` は Git 管理しないでください。
