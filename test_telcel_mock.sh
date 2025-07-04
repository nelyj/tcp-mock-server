#!/bin/bash

HOST="${1:-caboose.proxy.rlwy.net}"
PORT="${2:-17738}"

# Validar socat
if ! command -v socat &>/dev/null; then
  echo "❌ socat no está instalado. Instálalo con: sudo apt install socat"
  exit 1
fi

# FIFO para escribir, archivo para leer respuestas
PIPE=$(mktemp -u)
mkfifo "$PIPE"
RESP_FILE="responses_raw.log"

# Iniciar socat (una única conexión)
socat -v - TCP:"$HOST":"$PORT" < "$PIPE" > "$RESP_FILE" &
SOCAT_PID=$!

# Cleanup
cleanup() {
  echo -e "\n🧹 Cerrando conexión y limpiando..."
  kill "$SOCAT_PID" 2>/dev/null
  rm -f "$PIPE"
  exit 0
}
trap cleanup SIGINT SIGTERM

# Esperar a que socat esté listo
sleep 1

# Timestamp
fecha=$(date +%d%m%Y)
hora=$(date +%H%M%S)

# ➤ Enviar mensaje 98DU (ECHO)
echo -e "\n🚀 Enviando 98DU (ECHO)"
echo -ne "\x0298DU000001${fecha}${hora}\x03" > "$PIPE"

sleep 1

# ➤ Enviar mensaje 13DU (Pago de Factura)
echo -e "\n🚀 Enviando 13DU (Pago de Factura)"
pago=$'\x02'13DU000001"${fecha}${hora}"123456789000001TERM001234"${hora}${fecha}"123456789055512345001234567890123000001250010$'\x03'
echo -ne "$pago" > "$PIPE"

sleep 2

# Cerrar conexión
cleanup

# Extraer respuestas específicas
grep '99DU' "$RESP_FILE" > response_echo.txt
grep '14DU' "$RESP_FILE" > response_pago.txt

echo -e "\n✅ Respuestas guardadas:"
echo "  📄 response_echo.txt"
echo "  📄 response_pago.txt"