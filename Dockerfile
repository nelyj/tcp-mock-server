# Imagen base oficial de Go
FROM golang:1.21

# Setea el directorio de trabajo
WORKDIR /app

# Copia los archivos de módulos si existen
COPY go.mod .     
COPY go.sum .     

# Descarga dependencias (opcional si no hay)
RUN go mod tidy || true

# Copia todo el contenido de tu proyecto
COPY . .

# Compila el servidor TCP
RUN go build -v -o tcp-server main.go

# Expón el puerto TCP en el que escucha el servidor
EXPOSE 9000

# Comando de arranque
CMD ["./tcp-server"]