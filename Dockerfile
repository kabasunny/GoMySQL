# Dockerfile
FROM golang:1.20-alpine

# 作業ディレクトリを設定
WORKDIR /app

# Go Modulesのキャッシュを利用するためにgo.modとgo.sumをコピー
COPY app/go.mod app/go.sum ./

# 依存関係をダウンロード
RUN go mod download

# アプリケーションのソースコードをコピー
COPY app/. .

# アプリケーションをビルド
RUN go build -o main .

# アプリケーションを実行
CMD ["./main"]