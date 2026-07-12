# nnn Ubuntu Installer

nnn を Ubuntu 本番サーバへ入れるための公開インストーラーです。

このリポジトリに秘密情報は入れません。nnn 本体は private repository のままなので、インストール中に表示される Deploy Key を GitHub に登録しない限り clone はできません。

## 使い方

```bash
curl -fsSL https://raw.githubusercontent.com/Nishi0622/insatll-ubuntu/main/install-ubuntu.sh -o install-ubuntu.sh
sudo bash install-ubuntu.sh
```

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

## 注意

- GitHub の Deploy Key は `Allow write access` をオフにしてください。
- 管理画面ポート `3001` は Cloudflare Tunnel に公開しない運用を推奨します。
- DB、画像、`nnn.config.json` は Git 管理しないでください。
