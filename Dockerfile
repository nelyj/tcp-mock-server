FROM golang:1.24

WORKDIR /app

COPY . .

RUN go build -x -o tcp-server main.go

EXPOSE 9000

CMD ["./tcp-server"]