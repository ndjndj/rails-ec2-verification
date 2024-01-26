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

### 1. EC2 インスタンスを起動しておく

使用したインスタンスに関する情報は下記のとおりです。  
nginx + Ruby on Rails + Postgresql なら t2.micro で十分でしたが、ここは適宜変更してください。  
ストレージに関しても、イメージサイズに応じて変更してください。  
セキュリティグループは、インバウンドの SSH と HTTP を許可する設定にしてください。

|name|value|
|-|-|
|インスタンスタイプ|t2.micro|
|AMI|Ubuntu|
|ストレージ|20GB|

1. Docker CE をインストールする

SSH クライアントを使用するなりして、下記のように EC2 インスタンスに、 Docker CE をインストールします。  

```bash
# 古いパッケージの削除
sudo apt-get remove docker docker-engine docker.io containerd runc
# パッケージの更新
sudo apt-get update
# 関連パッケージのインストール
sudo apt-get install ca-certificates curl gnupg lsb-release
# Docker の GPG キー(暗号化ツールのキー)をインストール
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Docker のリポジトリ情報を apt に追加しパッケージとして利用することができるようにする
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 確認と更新
sudo apt-get update
# Docker CE のインストール
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# docker というグループユーザーを追加する
# ※自動的に追加されている場合があります
sudo groupadd docker

# 現在ログインしているユーザーを docker グループに追加する
sudo usermod -aG docker $USER
```

### 2. EC2 で動かすためにローカルで行う作業

1. ruby file の書き換え
    既に用意されている nginx と通信するために設定を変更していく。  

    _rails/config/puma.rb を参考に、config/puma.rb を書き換える。  
    ポイントは、Port の設定を無効にすることと、nginx の設定を bind させること  

    ```rb
    # config/puma.rb
    # port 設定を無効にする
    # port ENV.fetch("PORT") { 3000 }

    # -------------中略-------------

    # nginx の設定を bind させる
    app_root = File.expand_path("..", __dir__)
    bind "unix://#{app_root}/tmp/sockets/puma.sock"
    ```

    また、ホストの許可設定も追加する
    ```rb 
    # confg/environments/development.rb 

    # -------------中略-------------
    config.hosts << "<ec2 パブリック IPv4 DNS>"
    ```


2. DockerImage の build


    ```bash
    docker compose -f compose.verification.yml build --no-cache
    ```

3. 試しに up もしてみる

    ```bash
    docker compose -f compose.verification.yml up
    ```

4. EC2 に送るソース一式を圧縮する
    任意のディレクトリの圧縮ファイルを作成します。  
    このファイルを EC2 に送信、EC2 で解凍します。  
    今回は、rails-ec2-verification/ でリポジトリごと圧縮しています。

    ```bash
    tar zcvf app.tar.gz ./
    ```

5. EC2 に送るように DockerImage を tar ファイルに変換する
    nginx, Postgresql, rails の DockerImage を tar 形式で save します。  
    その後、EC2 に転送するために gzip 形式での圧縮も行います。

    ```
    # 対象の DockerImage の ImageID を特定する
    docker images 
    
    mkdir docker-images 
    cd docker-images 
    docker save <nginx image ID> > nginx.tar
    docker save <postgresql image ID> > postgres.tar
    docker save <rails image ID> > rails.tar

    tar zcvf docker-images.tar.gz ./
    ```
    この方法を使わない場合は、次の「5. EC2 に DockerImage を送信する」をスキップしてください。  
    EC2 の中で build をしてもいいのですが、gem のサイズによっては bundle install をしているときにマシンの CPU リソースが枯渇してしまう場合があります。  
    なので、転送に時間がかかってしまいますが、DockerImage はローカルで作ってしまうこちらの方法の方が確実です。  


6. compose.verification.yml の build 対象を変更する
    
    下記のように、DockerImage から build するように設定を変更します。  
    rails コンテナが肥大するので、rails だけ指定しています。  

    Rails App のコンテナ ID を調べます。  
    ```
    docker images
    ```

    ```yaml
    version: '3'
    services: 
      web: 
      db:
      rails: 
        image: <ローカルで build した DockerImage の image ID>
        #build: 
        #  context: ./rails
        #  dockerfile: ./Dockerfile.verification
        command: bash -c "rails s -b '0.0.0.0'"
        volumes:
          - ./rails:/usr/src/app
          - tmp-d:/usr/src/app/tmp
        depends_on:
          - db 
        tty: true 
        stdin_open: true
    volumes: 
      pg-data:
      tmp-d: 
      bin: 
        driver: local
    ```
7. EC2 に DockerImage を送信する

キーペアの指定とパスに注意してください。  
また WSL などで ホストをマウントしている場合は、permission error が発生することがあると思います。  
その場合は、ホスト側から送信する方法や、WSL 側に pem ファイルを移動したうえで権限変更などの方法を試してください。  

```
scp -i <pem ファイル> -r ../docker-images.tar.gz ubuntu@<ip>:/home/ubuntu/
scp -i <pem ファイル> -r ./app.tar.gz ubuntu@<ip>:/home/ubuntu/
```

### 3. EC2 で DockerImage からコンテナ群を立ち上げる

1. DockerImage を解凍、ロード

```
tar zxvf docker-images.tar.gz
docker load < docker-images/nginx.tar
docker load < docker-images/postgres.tar
docker load < docker-images/rails.tar
```

2. Rails App を解凍

```
sudo su -
cd /
mv /home/ubuntu/app.tar.gz /usr/src/app.tar.gz
cd usr/src 
tar zxvf /usr/src/app.tar.gz
```
3. Docker up

### 4. 動作確認

ブラウザで パブリック IPv4 DNS にアクセスして、Rails のいつもの画面が出てくることを確認する。
