FROM golang:1.21

WORKDIR /app

COPY go.mod .     

# Usa go mod tidy solo si tienes dependencias
RUN go mod tidy || true

COPY . .

RUN go build -v -o tcp-server main.go

EXPOSE 9000

CMD ["./tcp-server"]