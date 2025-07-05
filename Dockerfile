FROM golang:1.24

WORKDIR /app

COPY go.mod .
COPY . .

RUN go build -v -o tcp-server main.go

EXPOSE 9000

CMD ["./tcp-server"]