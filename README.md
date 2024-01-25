# rails-ec2-verification
RailsApp の検証用サーバーを EC2 で作成するためのテンプレートです  

## はじめに

- ベーシックな Nginx + Ruby on Rails + Postgresql の環境を、1台の EC2 上に構築するためのテンプレートです。  
- DynamoDB local などのその他の環境も加えて構築したい場合は、適宜カスタマイズしてください。

## 用途

- 検証用のプロトタイプを公開したいとき

## 流れ



## 使い方

### 0. 必要なファイル群を用意する  

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
    ├─ ...(他 Rails で必要なファイル群)
    ├─ Gemfile
    ├─ Gemfile.lock
    ├─ Dockerfile.verification
    └─ entrypoint.verification.sh
```

以下のどちらかで操作で /rails 直下に RailsApp のソースコード群を設置する。

- ( 選択肢 1 ) このリポジトリをテンプレートとして新しいリポジトリを作り、既存の Rails App をコピーしてくる

    このパターンの場合、以下の作業が必要

    - 下記ファイルの書き換え
        1. rails/config/puma.rb 
    - YourRailsApp/ に下記ファイルを _rails/ からコピーしてくる
        1. _rails/Dockerfile.verification 
        2. _rails/entrypoint.verification.sh 
    - compose.verification.yml を適宜書き換える

- ( 選択肢 2 ) このリポジトリをテンプレートとして新しいリポジトリを作り、新規 Rails App の開発を開始する

    1. 以下のコマンドを実行する

        ```bash
        docker compose run --rm rails rails new . --skip --database=postgresql --api --skip-bundle
        ```

    2. /rails/.git は削除しておく

### 1. EC2 で動かすためにローカルで行う作業

1. ( Local ) puma.rb の設定
    既に用意されている nginx と通信するために設定を変更していく。  

    _rails/config/puma.rb を参考に、config/puma.rb を書き換える。  
    ポイントは、Port を閉じることと、Nginx の設定を bind させること  

2. ( Local ) DockerImage の build


    ```bash
    docker compose -f compose.verification.yml build --no-cache
    ```

3. ( Local ) 試しに up もしてみる

    ```bash
    docker compose -f compose.verification.yml up
    ```

 4. ( Local ) 