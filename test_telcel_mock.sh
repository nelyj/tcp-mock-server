#!/bin/bash

HOST="${1:-caboose.proxy.rlwy.net}"
PORT="${2:-17738}"

 # Verifica que netcat esté instalado
if ! command -v nc &>/dev/null; then
  echo "❌ netcat (nc) no está instalado. Instálalo con: sudo apt install netcat"
  exit 1
fi

# Enviar mensaje de validación 98DU antes de cualquier 13DU
fecha=$(date +%d%m%Y)
hora=$(date +%H%M%S)
echo "📡 Enviando mensaje de validación (98DU)..."
echo -ne "\x0298DU000017${fecha}${hora}\x03" | nc $HOST $PORT
sleep 1

echo -e "\n✅ Conexión TCP interactiva con $HOST:$PORT"
echo "📡 Puedes enviar mensajes válidos Telcel (98DU, 13DU, 11DU)"
echo "📴 Presiona Ctrl+C para salir"

# Simulación de ECHO desde Telcel (96DU)
echo "🔁 Simulando ECHO desde Telcel (96DU)..."
echo -ne "\x0296DU000001$(date +%Y%m%d%H%M%S)\x03" | nc $HOST $PORT
sleep 1

# Documentación técnica de códigos de respuesta para 13DU:
# Código 00: Éxito - La transacción fue realizada correctamente.
# Código 01: Teléfono no existe
# Código 02: Importe incorrecto
# Código 03: Cliente no identificado
# Código 04: Cuenta vencida
# Código 05: Servicio no disponible
# Código 12: Inválida - La transacción es inválida o no autorizada.
# Código 51: Fondos insuficientes
# Código 54: Tarjeta vencida
# Código 61: Excede el límite de retiro
# Código 91: Emisor no disponible
# Código 99: Error no identificado
# Otros códigos pueden existir, consulte la documentación para detalles adicionales.

echo -e "\n📊 Enviando ejemplos de 13DU (Pago de Factura):"

# Lista de teléfonos con códigos esperados y descripciones
declare -A test_cases=(
  ["123456789000"]="00" # Éxito
  ["123456789001"]="01" # Teléfono no existe
  ["123456789002"]="02" # Importe incorrecto
  ["123456789003"]="03" # Cliente no identificado
  ["123456789004"]="04" # Cuenta vencida
  ["123456789005"]="05" # Servicio no disponible
  ["123456789009"]="99" # Error no identificado
)

for telefono in "${!test_cases[@]}"; do
  code="${test_cases[$telefono]}"
  transaction_id="07042025${telefono: -2}"
  echo "--- Enviando mensaje con teléfono: $telefono (esperado: código $code) ---"
  ./client.sh "$HOST" "$PORT" "$transaction_id" "$telefono"
done

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
      msg=$'\x0298DU000017'"${fecha}${hora}"$'\x03'
      echo "📦 Mensaje construido: $msg"
      ;;
    13DU)
      echo "🟡 Enviando mensaje tipo 13DU"
      msg=$'\x0213DU000017'"${fecha}${hora}"'123456789000001TERM001234'"${hora}${fecha}"'123456789055512345001234567890123000001250001'$'\x03'
      ;;
    11DU)
      echo "🟡 Enviando mensaje tipo 11DU"
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

transaction_id="0704202505"
telefono="1234567805"
echo "📨 Enviando 13DU con código de respuesta 05 (teléfono termina en 05)..."
./client.sh "$HOST" "$PORT" "$transaction_id" "$telefono"

transaction_id="0704202512"
telefono="1234567812"
echo "📨 Enviando 13DU con código de respuesta 12 (teléfono termina en 12)..."
./client.sh "$HOST" "$PORT" "$transaction_id" "$telefono"

transaction_id="0704202599"
telefono="1234567899"
echo "📨 Enviando 13DU con código de respuesta 99 (teléfono termina en 99)..."
./client.sh "$HOST" "$PORT" "$transaction_id" "$telefono"