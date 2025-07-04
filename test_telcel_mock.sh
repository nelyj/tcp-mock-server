#!/bin/bash

HOST="${1:-localhost}"
PORT="${2:-9000}"

fecha=$(date +%d%m%Y) # ddmmaaaa
hora=$(date +%H%M%S)  # hhmmss

function send_message() {
  local name="$1"
  local raw="$2"

  echo -ne "$raw" | nc "$HOST" "$PORT" | tee "response_${name}.txt"
  echo -e "\n:white_check_mark: Saved to response_${name}.txt"
}

echo ":arrows_counterclockwise: Testing Echo (98DU)..."
send_message "echo" "\x0298DU000001${fecha}${hora}\x03"

echo -e "\n:arrows_counterclockwise: Testing Pago de Factura (13DU)..."
message=$'\x02'13DU000001"${fecha}${hora}"123456789000001TERM001234"${hora}${fecha}"123456789055512345001234567890123000001250010$'\x03'
send_message "pago" "$message"

#echo -e "\n:arrows_counterclockwise: Testing Tiempo Aire (01DU)..."
# send_message "tiempoaire" "\x0201DU000001${timestamp}TX1234567890\x03"

# echo -e "\n:arrows_counterclockwise: Testing Venta de Servicio (21DU)..."
# send_message "servicio" "\x0221DU000001${timestamp}SRV1234567890\x03"

echo -e "\n:white_check_mark: Pruebas completadas contra $HOST:$PORT"