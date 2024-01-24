# rails-ec2-verification
RailsApp の検証用サーバーを EC2 で作成するためのテンプレートです  

## 用途

- 開発した API をクライアントから

## 流れ



## 使い方

0. 必要なファイル群を用意する  

    以下のようなディレクトリ構造にする必要があります。

    ```
    .
    ├─ compose.verification.yml
    ├─ nginx
    |   ├─ Dockerfile.verification
    |   └─ nginx.conf
    └─ rails
        ├─ app
        ├─ bin
        ├─ config
        ├─ ...(以下 Rails で必要なファイル群)
        ├─ Gemfile
        ├─ Gemfile.lock
        ├─ Dockerfile.verification
        └─ entrypoint.verification.sh
    ```

    以下のような操作で /rails 直下に RailsApp のソースコード群を設置する。
    
    - このリポジトリをテンプレートとして新しいリポジトリを作り、既存の Rails App をコピーしてくる

        - このパターンの場合、Gemfile などの Rails 系のファイルは不要です

            - ただし、既存ファイルの書き換えが必要な場合があります。

    - このリポジトリをテンプレートとして新しいリポジトリを作り、新規 Rails App の開発を開始する

        1. 以下のコマンドを実行する

        ```bash
        docker compose run --rm rails rails new . --skip --database=postgresql --api --skip-bundle
        ```

        2. /rails 直下で作成される .git フォルダを削除しておく


- 

```

```

- 
```

```

- 

```

```
 