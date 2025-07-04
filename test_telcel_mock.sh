#!/bin/bash

HOST="${1:-caboose.proxy.rlwy.net}"
PORT="${2:-17738}"

# Verifica que socat esté instalado
if ! command -v socat &>/dev/null; then
  echo "❌ socat no está instalado. Instálalo con: sudo apt install socat"
  exit 1
fi

# FIFO y archivo de respuestas
PIPE=$(mktemp -u)
mkfifo "$PIPE"
RESP_FILE="responses_raw.log"

# Inicia socat
socat -v - TCP:"$HOST":"$PORT" < "$PIPE" > "$RESP_FILE" &
SOCAT_PID=$!

# Esperar a que socat esté listo
sleep 1

# Cleanup
cleanup() {
  echo -e "\n🧹 Cerrando sesión TCP..."
  kill "$SOCAT_PID" 2>/dev/null
  rm -f "$PIPE"
  exit 0
}
trap cleanup SIGINT SIGTERM

# Timestamp inicial
fecha=$(date +%d%m%Y)
hora=$(date +%H%M%S)

# Info de sesión
echo -e "\n✅ Conexión TCP abierta con $HOST:$PORT"
echo "📡 Puedes enviar mensajes válidos Telcel (98DU, 13DU, etc.)"
echo "🔁 El servidor puede enviarte 96TL automáticamente"
echo "📴 Presiona Ctrl+C para cerrar la sesión"

# Lector de respuestas en background
(
  tail -f "$RESP_FILE" | while read -r line; do
    if [[ "$line" == *"99DU"* ]]; then
      echo "$line" >> response_echo.txt
    elif [[ "$line" == *"14DU"* ]]; then
      echo "$line" >> response_pago.txt
    elif [[ "$line" == *"12DU"* ]]; then
      echo "$line" >> response_monto.txt
    elif [[ "$line" == *"96TL"* ]]; then
      echo "$line" >> response_echo_96tl.txt
    fi
  done
) &

# Esperar entrada del usuario
while true; do
  echo -ne "\n📝 Ingrese mensaje a enviar (98DU, 13DU, 11DU) o 'exit': "
  read tipo
  fecha=$(date +%d%m%Y)
  hora=$(date +%H%M%S)

  case "$tipo" in
    98DU)
      echo -ne "\x0298DU000001${fecha}${hora}\x03" > "$PIPE"
      echo "✅ Enviado 98DU (Echo)"
      ;;

    13DU)
      msg=$'\x02'13DU000001"${fecha}${hora}"123456789000001TERM001234"${hora}${fecha}"123456789055512345001234567890123000001250010$'\x03'
      echo -ne "$msg" > "$PIPE"
      echo "✅ Enviado 13DU (Pago de Factura)"
      ;;

    11DU)
      msg=$'\x02'11DU000001"${fecha}${hora}"123456789000001TERM001234"${hora}${fecha}"55512345670000010000$'\x03'
      echo -ne "$msg" > "$PIPE"
      echo "✅ Enviado 11DU (Requerimiento de Monto)"
      ;;

    exit)
      cleanup
      ;;

    *)
      echo "❓ Tipo no válido: $tipo"
      ;;
  esac
done