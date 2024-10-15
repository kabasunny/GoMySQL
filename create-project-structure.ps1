# .env ファイルのパス
$envFilePath = ".env"

# .env ファイルの読み込み
if (Test-Path $envFilePath) {
  Get-Content $envFilePath | ForEach-Object {
      # 空行やコメント行を無視
      if ($_ -match "^\s*#") { return }
      if ($_ -match "^\s*$") { return }
      # 環境変数を設定
      $name, $value = $_ -split "=", 2
      $name = $name.Trim()
      $value = $value.Trim()
      [System.Environment]::SetEnvironmentVariable($name, $value)
  }
}

# 環境変数を使用
$rootPath = $env:ROOT_PATH
Write-Output "Root path is: $rootPath"

# プロジェクトディレクトリへ移動
cd $rootPath

# プロジェクトのルートディレクトリを作成
New-Item -ItemType Directory -Path api -Force

# API Dockerfile の作成
$apiDockerfileContent = @"
# Dockerfile
FROM golang:1.23

WORKDIR /app/api

COPY go.mod ./
COPY go.sum ./
RUN go mod download

# srcディレクトリを正しい場所にコピー
COPY src/ ./

# golang と air のインストール
RUN apt-get update && apt-get install -y golang-go
RUN go install github.com/air-verse/air@v1.61.0

ENV PATH="/go/bin:/usr/local/go/bin:${PATH}"

EXPOSE 8080
CMD ["air"]


"@
Set-Content -Path "$rootPath/api/Dockerfile" -Value $apiDockerfileContent -Force
Write-Output "Dockerfile for API has been created."

# APIのソースコードディレクトリを作成
New-Item -ItemType Directory -Path "$rootPath/api/src" -Force

# APIのmain.goの作成
$apiMainGoContent = @"
package main

import (
    "fmt"
    "gorm.io/driver/mysql"
    "gorm.io/gorm"
    "os"
    "time"
)

type User struct {
    ID        uint ``gorm:"primaryKey"``
    Username  string ``gorm:"unique;not null"``
    Email     string ``gorm:"unique;not null"``
    Password  string ``gorm:"not null"``
    CreatedAt time.Time
}

func main() {
    dsn := fmt.Sprintf("%s:%s@tcp(%s:3306)/%s?charset=utf8mb4&parseTime=True&loc=Local",
        os.Getenv("MYSQL_USER"),
        os.Getenv("MYSQL_PASSWORD"),
        os.Getenv("MYSQL_HOST"),
        os.Getenv("MYSQL_DB"))

    var db *gorm.DB
    var err error

    // データベース接続のリトライ
    for i := 0; i < 10; i++ {
        db, err = gorm.Open(mysql.Open(dsn), &gorm.Config{})
        if err == nil {
            break
        }
        fmt.Println("Database connection failed. Retrying in 5 seconds...")
        time.Sleep(5 * time.Second)
    }

    if err != nil {
        panic("failed to connect database")
    }

    db.AutoMigrate(&User{})
}
"@
# UTF-8エンコーディングでファイルを書き込む
[System.IO.File]::WriteAllText("$rootPath/api/src/main.go", $apiMainGoContent, [System.Text.Encoding]::UTF8)
Write-Output "main.go for API has been created."

# go.modの作成
if (-Not (Test-Path "$rootPath/api/go.mod")) {
    cd "$rootPath/api"
    go mod init api
    go get gorm.io/gorm
    go get gorm.io/driver/mysql
    go mod tidy
    cd ..
}

# docker-compose.yml の作成
$dockerComposeContent = @"
version: '3.8'
services:
  api:
    build: ./api
    ports:
      - "8084:8080"
    environment:
      MYSQL_HOST: mysql
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      MYSQL_DB: ${MYSQL_DB}
    depends_on:
      - mysql

  mysql:
    image: mysql:8
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql

  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    environment:
      PMA_HOST: mysql
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    ports:
      - "84:80"
    depends_on:
      - mysql

volumes:
  mysql_data:
"@
Set-Content -Path "$rootPath/docker-compose.yml" -Value $dockerComposeContent -Force
Write-Output "docker-compose.yml has been created."

# Dockerコンテナの起動
cd $rootPath
docker-compose up --build

Write-Output "Project structure has been created."