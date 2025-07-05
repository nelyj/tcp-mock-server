#!/bin/bash

HOST=${1:-localhost}
PORT=${2:-9000}

send_message() {
  local transaction_id=$1
  local telefono=$2
  local message="\x0213DU000001${transaction_id}025212540123456789000001TERM001234212508040720251234567890${telefono}12345678905551233000001250001.\x03"
  echo -e "$message" | nc $HOST $PORT
  echo -e "\n--- Enviando mensaje con teléfono: ${telefono} (esperado: código ${telefono: -2}) ---"
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
echo "--- Enviando mensaje con teléfono: 123456789001 (esperado: código 01 - Teléfono no existe) ---"
send_message "0704202523" "123456789002" # => 02
echo "--- Enviando mensaje con teléfono: 123456789002 (esperado: código 02 - Importe incorrecto) ---"
send_message "0704202524" "123456789003" # => 03
echo "--- Enviando mensaje con teléfono: 123456789003 (esperado: código 03 - Cliente no identificado) ---"
send_message "0704202525" "123456789004" # => 04
echo "--- Enviando mensaje con teléfono: 123456789004 (esperado: código 04 - Cuenta vencida) ---"
send_message "0704202526" "123456789005" # => 05
echo "--- Enviando mensaje con teléfono: 123456789005 (esperado: código 05 - Servicio no disponible) ---"
send_message "0704202527" "123456789099" # => 99
echo "--- Enviando mensaje con teléfono: 123456789099 (esperado: código 99 - Error general) ---"
send_message "0704202528" "123456789XX"  # => error no reconocido, forzado
echo "--- Enviando mensaje con teléfono: 123456789XX (esperado: código XX - Error no reconocido) ---"

echo "✅ Tests completados. Revisa los logs del servidor para confirmar las respuestas."

# Simulación de respuesta 97TL eliminada. Se manejará dentro del mock.