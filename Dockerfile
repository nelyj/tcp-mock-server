# Usa una imagen base de Go
FROM golang:1.21

# Crea el directorio de trabajo
WORKDIR /app

# Copia el código fuente
COPY . .

# Compila el binario
RUN go build -o tcp-server .

# Expón el puerto TCP (por defecto usas 9000)
EXPOSE 9000

# Comando para iniciar el servidor
CMD ["./tcp-server"]