# はじめに
RailsApp の検証用サーバーを EC2 で作成するためのテンプレートです  

- ベーシックな Nginx + Ruby on Rails + Postgresql の環境を、1台の EC2 上に構築するためのテンプレートです。  
- DynamoDB local などのその他の環境も加えて構築したい場合は、適宜カスタマイズしてください。

# 用途

- 検証用のプロトタイプを公開したいとき

# 流れ


# 0. 必要なファイル群を用意する  

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
        2. rails/environments/development.rb
    - YourRailsApp/ に下記ファイルを _rails/ からコピーしてくる
        1. _rails/Dockerfile.verification 
        2. _rails/entrypoint.verification.sh 
    - compose.verification.yml を適宜書き換える

- ( 選択肢 2 ) このリポジトリをテンプレートとして新しいリポジトリを作り、新規 Rails App の開発を開始する

    1. 以下のコマンドを実行して RailsApp の開発を開始する
        rails new のオプションは適宜変更してください。
        下記は API モードで作成しています。

        ```bash
        docker compose run --rm rails rails new . --skip --database=postgresql --api --skip-bundle
        ```

    2. /rails/.git は削除しておく

# 1. EC2 インスタンスの準備

使用したインスタンスに関する情報は下記のとおりです。  
検証したところ、nginx + Ruby on Rails + Postgresql なら t2.micro で十分でしたが、ここは適宜変更してください。  
ストレージに関しても、イメージサイズに応じて変更してください。  
セキュリティグループは、インバウンドの SSH と HTTP を許可する設定にしてください。

|name|value|
|-|-|
|インスタンスタイプ|t2.micro|
|AMI|Ubuntu|
|ストレージ|20GB|

## 1-1. Docker CE をインストールする

SSH クライアントを使用するなりして、EC2 インスタンスに Docker CE をインストールします。  

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

# 2. EC2 で動かすためにローカルで行う作業

## 2-1. ruby file の書き換え
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


## 2-2. DockerImage の build

```bash
docker compose -f compose.verification.yml build --no-cache
```

## 2-3. 試しに up もしてみる

```bash
docker compose -f compose.verification.yml up
```

## 2-4. EC2 に送るソース一式を圧縮する

任意のディレクトリの圧縮ファイルを作成します。  
このファイルを EC2 に送信し、解凍します。  
今回は、rails-ec2-verification/ でリポジトリごと圧縮しています。

```bash
tar zcvf app.tar.gz ./
```

## 2-5. EC2 に送るように DockerImage を tar ファイルに変換する

nginx, Postgresql, rails の DockerImage を tar 形式で save します。  
その後、EC2 に転送するために gzip 形式での圧縮も行います。

```
# 対象の DockerImage の ImageID を特定する
docker images 

# アーカイブ
mkdir docker-images 
cd docker-images 
docker save <nginx image ID> > nginx.tar
docker save <postgresql image ID> > postgres.tar
docker save <rails image ID> > rails.tar

# 圧縮
tar zcvf docker-images.tar.gz ./
```

この方法を使わない場合は、「3-2. Rails App を解凍」までスキップしてください。  
ただ、EC2 の中で build をしてもいいのですが、gem のサイズによっては bundle install をしているときにマシンの CPU リソースが枯渇してしまう場合があります。  
なので、転送に時間がかかってしまいますが、DockerImage はローカルで作ってしまうこちらの方法の方がおすすめです。  


## 2-6. compose.verification.yml の build 対象を変更する
    
下記のように、DockerImage から build するように設定を変更します。  

```bash
docker images
```

compose.verification.yml の設定を変更します。

```yaml
version: '3'
services: 
    web: 
    db:
    rails: 
    image: <image ID or repository:tag>
    # image: xxxxxxxxxxx ID 
    # image: raisl-ec2-verificaiton-rails:latest 
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

## 2-7. EC2 に DockerImage を送信する

キーペアの指定とパスに注意してください。  
また WSL などで ホストをマウントしている場合は、permission error が発生することがあると思います。  
その場合は、ホスト側から送信する方法や、WSL 側に pem ファイルを移動したうえで権限変更などの方法を試してください。  

```
scp -i <pem ファイル> -r ../docker-images.tar.gz ubuntu@<ip>:/home/ubuntu/
scp -i <pem ファイル> -r ./app.tar.gz ubuntu@<ip>:/home/ubuntu/
```

# 3. EC2 で DockerImage からコンテナ群を立ち上げる

## 3-1. DockerImage の設定

DockerImage をロードします。  
また、repository と tag が none になっているので、タグ付けもします。  
compose.yml で image ID を指定している場合は無視してください。ローカルと同じタグにしてください。
```bash
# 解凍
tar zxvf docker-images.tar.gz

# load 
docker load < docker-images/nginx.tar
docker load < docker-images/postgres.tar
docker load < docker-images/rails.tar

# タグづけ
docker images 
docker tag xxxxxxxx rails-ec2-verification-rails:latest
docker tag xxxxxxxx rails-ec2-verification-web:latest
```

## 3-2. Rails App を解凍

```
sudo su -
cd /
mv /home/ubuntu/app.tar.gz /usr/src/app.tar.gz
cd usr/src 
tar zxvf /usr/src/app.tar.gz
```
## 3-3. Docker up

```bash
docker compose -f compose.verification.yml up
```

# 4. 動作確認

ブラウザで パブリック IPv4 DNS にアクセスして、Rails のいつもの画面が出てくることを確認する。

# おまけ
インスタンス開始時に Docker compose up できるようにする。  

1. リポジトリの docker-up.sh を /var/lib/cloud/scripts/per-boot/ に設置する。
2. sudo systemctl enabled docker で docker デーモンを自動で起動するようにする。
