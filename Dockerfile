FROM golang:1.21

WORKDIR /app

COPY go.mod . 
COPY go.sum . 
COPY . .

RUN go build -v -o tcp-server main.go

EXPOSE 9000

CMD ["./tcp-server"]