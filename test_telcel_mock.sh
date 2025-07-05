#!/bin/bash

HOST="${1:-caboose.proxy.rlwy.net}"
PORT="${2:-17738}"

# Verifica que netcat esté instalado
if ! command -v nc &>/dev/null; then
  echo "❌ netcat (nc) no está instalado. Instálalo con: sudo apt install netcat"
  exit 1
fi

# Info de sesión
echo -e "\n✅ Conexión TCP interactiva con $HOST:$PORT"
echo "📡 Puedes enviar mensajes válidos Telcel (98DU, 13DU, 11DU)"
echo "📴 Presiona Ctrl+C para salir"

PIPE=$(mktemp -u)
mkfifo "$PIPE"
RESP_FILE="responses_raw_nc.log"

nc "$HOST" "$PORT" < "$PIPE" > "$RESP_FILE" &
NC_PID=$!

trap "echo '👋 Cerrando sesión...'; kill $NC_PID; rm -f $PIPE; exit 0" SIGINT

# Bucle interactivo
while true; do
  echo -ne "\n📝 Ingrese mensaje a enviar (98DU, 13DU, 11DU) o 'exit': "
  read tipo
  fecha=$(date +%d%m%Y)
  hora=$(date +%H%M%S)

  case "$tipo" in
    98DU)
      msg=$'\x0298DU000001'"${fecha}${hora}"$'\x03'
      ;;

    13DU)
      msg=$'\x0213DU000001'"${fecha}${hora}"123456789000001TERM001234"${hora}${fecha}"123456789055512345001234567890123000001250010$'\x03'
      ;;

    11DU)
      msg=$'\x0211DU000001'"${fecha}${hora}"123456789000001TERM001234"${hora}${fecha}"55512345670000010000$'\x03'
      ;;

    exit)
      echo "👋 Cerrando sesión..."
      kill $NC_PID
      rm -f $PIPE
      exit 0
      ;;

    *)
      echo "❓ Tipo no válido: $tipo"
      continue
      ;;
  esac

  echo -ne "$msg" > "$PIPE"
  echo "✅ Mensaje enviado"
  echo "📥 Esperando respuesta..."
  sleep 1
  tail -n 10 "$RESP_FILE"
done