#!/bin/bash

HOST="${1:-localhost}"
PORT="${2:-9000}"

timestamp=$(date +%Y%m%d%H%M%S)

function send_message() {
  local name="$1"
  local raw="$2"

  echo -ne "$raw" | nc "$HOST" "$PORT" | tee "response_${name}.txt"
  echo -e "\n✅ Saved to response_${name}.txt"
}

echo "🔄 Testing Echo (98DU)..."
send_message "echo" "\x0298DU000001${timestamp}\x03"

echo -e "\n🔄 Testing Pago de Factura (13DU)..."
# Mensaje de 83 bytes mínimo (hasta phone)
RELLENO=$(printf 'X%.0s' {1..60})
send_message "pago" "\x0213DU000001${timestamp}${RELLENO}5551234590\x03"

echo -e "\n🔄 Testing Tiempo Aire (01DU)..."
send_message "tiempoaire" "\x0201DU000001${timestamp}TX1234567890\x03"

echo -e "\n🔄 Testing Venta de Servicio (21DU)..."
send_message "servicio" "\x0221DU000001${timestamp}SRV1234567890\x03"

echo -e "\n✅ Pruebas completadas contra $HOST:$PORT"