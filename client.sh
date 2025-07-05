#!/bin/bash

HOST="${1:-localhost}"
PORT="${2:-9000}"

send_message() {
  local transaction_id=$1
  local telefono=$2
  local message="\x0213DU000001${transaction_id}025212540123456789000001TERM001234212508040720251234567890${telefono}12345678905551233000001250001.\x03"
  echo -e "$message" | nc $HOST $PORT
  echo -e "\n--- Sent 13DU with phone: $telefono (last 2 digits: ${telefono: -2}) ---"
}


# Enviar mensaje de validación 98DU antes de cualquier 13DU
fecha=$(date +%d%m%Y)
hora=$(date +%H%M%S)
echo "📡 Enviando mensaje de validación (98DU)..."
echo -ne "\x0298DU000017${fecha}${hora}\x03" | nc $HOST $PORT
sleep 1

echo "Starting Telcel Payment Tests with 13DU messages..."

# Casos correctos y errores según últimos dos dígitos del teléfono
send_message "0704202521" "123456789000" # => 00 (correcto)
send_message "0704202522" "123456789001" # => 01
send_message "0704202523" "123456789002" # => 02
send_message "0704202524" "123456789003" # => 03
send_message "0704202525" "123456789004" # => 04
send_message "0704202526" "123456789005" # => 05
send_message "0704202527" "123456789099" # => 99
send_message "0704202528" "123456789XX"  # => error no reconocido, forzado

echo "✅ Tests completados. Revisa los logs del servidor para confirmar las respuestas."