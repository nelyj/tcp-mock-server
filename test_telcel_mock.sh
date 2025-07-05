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
      echo "🟡 Enviando mensaje tipo 98DU"
      echo "📦 Mensaje construido: $msg"
      msg=$'\x0298DU000017'"${fecha}${hora}"$'\x03'
      echo "📦 Mensaje construido: $msg"
      ;;
    13DU)
      echo "🟡 Enviando mensaje tipo 13DU"
      echo "📦 Mensaje construido: $msg"
      msg=$'\x0213DU000017'"${fecha}${hora}"'123456789000001TERM001234'"${hora}${fecha}"'123456789055512345001234567890123000001250010'$'\x03'
      echo "📦 Mensaje construido: $msg"
      ;;
    11DU)
      echo "🟡 Enviando mensaje tipo 11DU"
      echo "📦 Mensaje construido: $msg"
      msg=$'\x0211DU000017'"${fecha}${hora}"'123456789000001TERM001234'"${hora}${fecha}"'55512345670000010000'$'\x03'
      echo "📦 Mensaje construido: $msg"
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

  # Mostrar tipo y mensaje (sin caracteres especiales)
  echo "🧾 Tipo seleccionado: $tipo"
  echo "📤 Mensaje hexadecimal (debug):"
  echo -n "$msg" | xxd
  echo "📤 Mensaje como texto plano (debug):"
  echo "$msg" | tr -d '\x02\x03'

  # Mostrar el contenido exacto del mensaje con delimitadores visibles
  echo "🔎 Mensaje exacto (delimitado): >>>$msg<<<"

  # Cierra y reabre el pipe para cada mensaje para evitar reutilizar buffer anterior
  exec 3>&-  # Cierra descriptor si está abierto
  exec 3>"$PIPE"  # Abre para escritura
  echo -ne "$msg" >&3
  exec 3>&-  # Cierra inmediatamente después de escribir
  # echo -ne "$msg" > "$PIPE"
  echo -ne "$msg" > "$PIPE" &
  echo "✅ Mensaje enviado"
  echo "📥 Esperando respuesta..."
  sleep 1
  tail -n 10 "$RESP_FILE"
done