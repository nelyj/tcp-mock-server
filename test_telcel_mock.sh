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

# Documentación técnica de códigos de respuesta para 13DU:
# Código 00: Éxito - La transacción fue realizada correctamente.
# Código 03: Comercio inválido
# Código 04: Tarjeta expirada
# Código 05: Denegada - La transacción fue denegada por el banco emisor.
# Código 12: Inválida - La transacción es inválida o no autorizada.
# Código 51: Fondos insuficientes
# Código 54: Tarjeta vencida
# Código 61: Excede el límite de retiro
# Código 91: Emisor no disponible
# Código 99: Error general - Error general del sistema, transacción no procesada.
# Otros códigos pueden existir, consulte la documentación para detalles adicionales.

echo -e "\n📊 Enviando ejemplos de 13DU (Pago de Factura):"

echo "📨 Enviando 13DU con código de respuesta 00 (Éxito: Transacción realizada)"
telefono="1234567800"
./client.sh "13DU" "$telefono"

echo "📨 Enviando 13DU con código de respuesta 03 (Comercio inválido)"
telefono="1234567803"
./client.sh "13DU" "$telefono"

echo "📨 Enviando 13DU con código de respuesta 04 (Tarjeta expirada)"
telefono="1234567804"
./client.sh "13DU" "$telefono"

echo "📨 Enviando 13DU con código de respuesta 05 (Denegada por el banco emisor)"
telefono="1234567805"
./client.sh "13DU" "$telefono"

echo "📨 Enviando 13DU con código de respuesta 12 (Transacción inválida)"
telefono="1234567812"
./client.sh "13DU" "$telefono"

echo "📨 Enviando 13DU con código de respuesta 51 (Fondos insuficientes)"
telefono="1234567851"
./client.sh "13DU" "$telefono"

echo "📨 Enviando 13DU con código de respuesta 54 (Tarjeta vencida)"
telefono="1234567854"
./client.sh "13DU" "$telefono"

echo "📨 Enviando 13DU con código de respuesta 61 (Excede el límite de retiro)"
telefono="1234567861"
./client.sh "13DU" "$telefono"

echo "📨 Enviando 13DU con código de respuesta 91 (Emisor no disponible)"
telefono="1234567891"
./client.sh "13DU" "$telefono"

echo "📨 Enviando 13DU con código de respuesta 99 (Error general del sistema)"
telefono="1234567899"
./client.sh "13DU" "$telefono"

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
      msg=$'\x0213DU000017'"${fecha}${hora}"'123456789000001TERM001234'"${hora}${fecha}"'123456789055512345001234567890123000001250001'$'\x03'
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

echo "📨 Enviando 13DU con código de respuesta 05 (teléfono termina en 05)..."
telefono="1234567805"
./client.sh "13DU" "$telefono"

echo "📨 Enviando 13DU con código de respuesta 12 (teléfono termina en 12)..."
telefono="1234567812"
./client.sh "13DU" "$telefono"

echo "📨 Enviando 13DU con código de respuesta 99 (teléfono termina en 99)..."
telefono="1234567899"
./client.sh "13DU" "$telefono"