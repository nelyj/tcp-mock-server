#!/bin/bash

HOST="${1:-localhost}"
PORT="${2:-9000}"

# Función para enviar mensaje por socket y cerrarlo correctamente
send_message() {
  local msg="$1"
  echo -e "🧾 Mensaje enviado (hex): $(echo -n "$msg" | hexdump -C)"
  echo -e "📏 Longitud del mensaje enviado: ${#msg} caracteres"
  exec 3<>/dev/tcp/$HOST/$PORT
  echo -ne "$msg" >&3
  # Esperar respuesta de manera síncrona antes de cerrar
  local response
  response=$(timeout 2 cat <&3)
  echo -e "📥 Respuesta recibida (crudo): $response"

  # Extraer payload entre STX (0x02) y ETX (0x03)
  local clean_payload=$(echo -n "$response" | tr -d '\r\n' | sed -e 's/.*\x02\(.*\)\x03.*/\1/')
  local length=${#clean_payload}
  echo -e "📦 Payload recibido (${length} caracteres): $clean_payload"

  if [[ "$response" != *$'\x02'* || "$response" != *$'\x03'* ]]; then
    echo -e "⚠️ Respuesta no tiene formato esperado con delimitadores STX/ETX"
  fi

  exec 3<&-
  exec 3>&-
  # Validación de longitud por acción usando solo el cuerpo (sin delimitadores)
  if [[ -n "$clean_payload" ]]; then
    accion="${clean_payload:0:2}"
    case "$accion" in
      "12")
        expected_length=124
        ;;
      "14")
        expected_length=116
        ;;
      "11")
        expected_length=96
        ;;
      "13")
        expected_length=108
        ;;
      "96"|"97"|"98"|"99")
        expected_length=24
        ;;
      *)
        expected_length=0
        ;;
    esac
    if [ "$expected_length" -ne 0 ]; then
      echo "Respuesta Acción $accion: longitud = $length (esperado = $expected_length)"
      if [ "$length" -eq "$expected_length" ]; then
        echo "✅ Acción $accion OK"
      else
        echo "❌ Acción $accion longitud incorrecta"
      fi
    fi
  fi
}

# Acción 13 – Requerimiento de Pago de Factura (108 caracteres sin STX/ETX)
# Acción:              2   => "13"
# ID:                  8   => "DU000001"
# Fecha:               8   => "05072025"
# Hora:                6   => "120000"
# Cadena Comercial:    10  => "CADENA1234"
# Tienda:              5   => "T0012"
# Terminal:           10   => "TERM0012345"
# Hora Local:          6   => "120000"
# Fecha Local:         8   => "20250705"
# Folio:              10   => TXID (ej. "0704202501")
# Teléfono:           10   => phone (ej. "1234567890")
# CUR:                13   => "1234567890123"
# Monto:              10   => "0000100000"
# Compromiso Pago:     2   => "10"
# Total: 108 caracteres
send_13du() {
  local txid=$(printf "%010s" "$1")          # 10
  local phone=$(printf "%010s" "$2")         # 10
  local fecha_ddmmaaaa=$(date +%d%m%Y)       # 8
  local hora=$(date +%H%M%S)                 # 6
  local cadena=$(printf "%-10s" "CADENA1234") # 10
  local tienda=$(printf "%-5s" "T0012")      # 5
  local terminal=$(printf "%-10s" "TERMINAL01") # 10
  local hora_local="$hora"                   # 6
  local fecha_local=$(date +%Y%m%d)          # 8
  local folio="$txid"                        # 10
  local cur=$(printf "%013s" "1234567890123") # 13
  local monto="0000100000"                   # 10
  local compromiso_pago="10"                 # 2

  # Construcción campo a campo:
  local payload=$(printf "13DU000001%s%s%s%s%s%s%s%s%s%s%s%s" \
    "$fecha_ddmmaaaa" \
    "$hora" \
    "$cadena" \
    "$tienda" \
    "$terminal" \
    "$hora_local" \
    "$fecha_local" \
    "$folio" \
    "$phone" \
    "$cur" \
    "$monto" \
    "$compromiso_pago" \
  )

  clean_payload=$(echo "$payload" | tr -d '\r' | sed -n 's/.*\x02\(.*\)\x03.*/\1/p')
  payload_length=${#payload}
  echo "📦 Payload recibido ($payload_length caracteres): $payload"
  accion="${payload:0:2}"
  case "$accion" in
    "11")
      echo "🔍 Acción 11 - Consulta Monto Factura (96 caracteres esperados)"
      echo "  Campo Acción:              2 (${payload:0:2})"
      echo "  Campo ID:                  8 (${payload:2:8})"
      echo "  Campo Fecha (ddmmaaaa):    8 (${payload:10:8})"
      echo "  Campo Hora (hhmmss):       6 (${payload:18:6})"
      echo "  Cadena Comercial:         10 (${payload:24:10})"
      echo "  Tienda:                    5 (${payload:34:5})"
      echo "  Terminal:                 10 (${payload:39:10})"
      echo "  Hora Local:                6 (${payload:49:6})"
      echo "  Fecha Local:               8 (${payload:55:8})"
      echo "  Folio:                    10 (${payload:63:10})"
      echo "  Teléfono:                 10 (${payload:73:10})"
      echo "  CUR:                      13 (${payload:83:13})"
      ;;
    "12")
      echo "🔍 Acción 12 - Respuesta Consulta (124 caracteres esperados)"
      echo "  Campo Acción:              2 (${payload:0:2})"
      echo "  Campo ID:                  8 (${payload:2:8})"
      echo "  Campo Fecha:               8 (${payload:10:8})"
      echo "  Campo Hora:                6 (${payload:18:6})"
      echo "  Cadena Comercial:         10 (${payload:24:10})"
      echo "  Tienda:                    5 (${payload:34:5})"
      echo "  Terminal:                 10 (${payload:39:10})"
      echo "  Hora Local:                6 (${payload:49:6})"
      echo "  Fecha Local:               8 (${payload:55:8})"
      echo "  Folio:                    10 (${payload:63:10})"
      echo "  Teléfono:                 10 (${payload:73:10})"
      echo "  CUR:                      13 (${payload:83:13})"
      echo "  Saldo Estimado:           10 (${payload:96:10})"
      echo "  Saldo Actual:             10 (${payload:106:10})"
      echo "  Código de Respuesta:       2 (${payload:116:2})"
      echo "  Nº Transacción Telcel:     6 (${payload:118:6})"
      ;;
    "13")
      echo "🔍 Acción 13 - Requerimiento de Pago (108 caracteres esperados)"
      echo "  Campo Acción:              2 (${payload:0:2})"
      echo "  Campo ID:                  8 (${payload:2:8})"
      echo "  Campo Fecha:               8 (${payload:10:8})"
      echo "  Campo Hora:                6 (${payload:18:6})"
      echo "  Cadena Comercial:         10 (${payload:24:10})"
      echo "  Tienda:                    5 (${payload:34:5})"
      echo "  Terminal:                 10 (${payload:39:10})"
      echo "  Hora Local:                6 (${payload:49:6})"
      echo "  Fecha Local:               8 (${payload:55:8})"
      echo "  Folio:                    10 (${payload:63:10})"
      echo "  Teléfono:                 10 (${payload:73:10})"
      echo "  CUR:                      13 (${payload:83:13})"
      echo "  Monto:                    10 (${payload:96:10})"
      echo "  Compromiso de Pago:        2 (${payload:106:2})"
      ;;
    "14")
      echo "🔍 Acción 14 - Respuesta a Pago (120 caracteres esperados)"
      echo "  Campo Acción:              2 (${payload:0:2})"
      echo "  Campo ID:                  8 (${payload:2:8})"
      echo "  Campo Fecha:               8 (${payload:10:8})"
      echo "  Campo Hora:                6 (${payload:18:6})"
      echo "  Cadena Comercial:         10 (${payload:24:10})"
      echo "  Tienda:                    5 (${payload:34:5})"
      echo "  Terminal:                 10 (${payload:39:10})"
      echo "  Hora Local:                6 (${payload:49:6})"
      echo "  Fecha Local:               8 (${payload:55:8})"
      echo "  Folio:                    10 (${payload:63:10})"
      echo "  Teléfono:                 10 (${payload:73:10})"
      echo "  CUR:                      13 (${payload:83:13})"
      echo "  Monto:                    10 (${payload:96:10})"
      echo "  Compromiso de Pago:        2 (${payload:106:2})"
      echo "  Código de Respuesta:       2 (${payload:108:2})"
      echo "  Nº Transacción Telcel:     6 (${payload:110:6})"
      ;;
    "96"|"97"|"98"|"99")
      echo "🔍 Acción $accion - Echo (24 caracteres esperados)"
      echo "  Campo Acción:              2 (${payload:0:2})"
      echo "  Campo ID:                  8 (${payload:2:8})"
      echo "  Campo Fecha:               8 (${payload:10:8})"
      echo "  Campo Hora:                6 (${payload:18:6})"
      ;;
    *)
      echo "⚠️ Acción no reconocida: $accion"
      ;;
  esac

  body="${payload:0:${#payload}}"
  echo "📤 Longitud mensaje enviado: ${#body} (esperada: 108)"
  if [ ${#body} -ne 108 ]; then
    echo "❌ Longitud incorrecta en mensaje enviado."
  else
    echo "✅ Longitud correcta en mensaje enviado."
  fi

  local msg=$(printf "\x02%s\x03" "$payload")

  echo -e "🧾 Payload (texto): $payload"
  echo -e "🧾 Payload (hex): $(echo -n "$payload" | hexdump -C)"
  echo -e "📏 Longitud payload (sin STX/ETX): ${#payload}"

  echo "[Acción 13] Longitud: ${#msg} caracteres"
  echo -e "\n📤 Enviando 13DU con teléfono: $phone y TXID: $txid"

  # --- Restaurar la lógica correcta para leer respuesta tras enviar ---
  echo -e "🧪 Acción 13DU"
  local respuesta=""
  exec 3<> /dev/tcp/$HOST/$PORT
  echo -ne "$msg" >&3
  respuesta=""
  # Leer hasta ETX (0x03) o timeout
  while IFS= read -r -t 5 -n 1 c <&3; do
    respuesta+="$c"
    [[ "$c" == $'\x03' ]] && break
  done
  exec 3<&-
  exec 3>&-
  # Mostrar respuesta recibida
  echo -e "🧾 Respuesta recibida: $respuesta"
  echo -e "📏 Longitud respuesta: ${#respuesta}"
  # 📨 Log especial requerido
  echo -e "📨 Respuesta recibida (${#respuesta} caracteres): $respuesta"
  # Extraer payload limpio y validar para acción 14
  payload_14=$(echo -n "$respuesta" | tr -d '\r\n' | sed -e 's/.*\x02\(.*\)\x03.*/\1/')
  if [[ -n "$payload_14" && "${payload_14:0:2}" == "14" ]]; then
    if [ ${#payload_14} -ne 116 ]; then
      echo "❌ Acción 14 longitud incorrecta (esperada: 116, recibida: ${#payload_14})"
    else
      echo "✅ Acción 14 longitud correcta (116 caracteres)"
    fi
  fi
}

# Acción 11 – Requerimiento de Monto de Factura (96 caracteres sin STX/ETX)
# Acción:         2   => "11"
# ID:             8   => "DU000001"
# Fecha:          8   => "05072025"
# Hora:           6   => "120000"
# Cadena:        10   => "1234567890"
# Tienda:         5   => "12345"
# Terminal:      10   => "TERMINAL01"
# Hora Local:     6   => "120000"
# Fecha Local:    8   => "20250705"
# Folio:         10   => "0000001234"
# Teléfono:      10   => "5566778899"
# CUR:           13   => "1234567890123"
# Total: 96 caracteres
send_11du() {
  # --- Construcción de variables para payload11 ---
  local fecha="05072025"      # 8
  local hora="053603"         # 6
  local cadena="CADENA1234"   # 10
  local tienda="T0012"        # 5
  local terminal="TERMINAL01" # 10
  local hora_local="053603"   # 6
  local fecha_local="20250705" # 8
  local folio="0704202501"    # 10
  local telefono="1234567890" # 10
  local cur="1234567890123"   # 13

  # Permitir sobreescribir folio y teléfono si se pasan como argumento
  if [ -n "$1" ]; then folio="$1"; fi
  if [ -n "$2" ]; then telefono="$2"; fi

  # Construcción exacta del payload11
  payload11="11DU000001${fecha}${hora}${cadena}${tienda}${terminal}${hora_local}${fecha_local}${folio}${telefono}${cur}"

  echo "📦 Payload 11DU: $payload11"
  echo "Longitud payload11: ${#payload11}"

  # Enviar por TCP y leer respuesta como en 13DU
  local mensaje
  mensaje=$(printf "\x02%s\x03" "$payload11")
  exec 3<> /dev/tcp/$HOST/$PORT
  echo -ne "$mensaje" >&3
  # Leer hasta ETX (0x03) o timeout
  local respuesta=""
  while IFS= read -r -t 5 -n 1 c <&3; do
    respuesta+="$c"
    [[ "$c" == $'\x03' ]] && break
  done
  exec 3<&-
  exec 3>&-
  echo "📨 Esperando respuesta del servidor..."
  RESPONSE=$(timeout 2 nc -w1 localhost 9000)
  echo "📥 Respuesta recibida: $RESPONSE"
  echo "📏 Longitud de respuesta: ${#RESPONSE}"

  if [[ "$RESPONSE" == 12DU* ]]; then
    echo "✅ Acción 12 longitud correcta (${#RESPONSE} caracteres)"
  else
    echo "❌ Acción 12 respuesta no reconocida o longitud incorrecta"
  fi
}

# Acción 96 – Solicitud de Echo (24 caracteres sin STX/ETX)
# Acción:  2 => "96"
# ID:      8 => "DU000001"
# Fecha:   8 => "05072025"
# Hora:    6 => "120000"
# Total: 24 caracteres
send_echo() {
  local fecha=$(date +%d%m%Y)   # 8
  local hora=$(date +%H%M%S)    # 6
  local payload=$(printf "96DU000001%s%s" "$fecha" "$hora")

  clean_payload=$(echo "$payload" | tr -d '\r' | sed -n 's/.*\x02\(.*\)\x03.*/\1/p')
  payload_length=${#payload}
  echo "📦 Payload recibido ($payload_length caracteres): $payload"
  accion="${payload:0:2}"
  case "$accion" in
    "11")
      echo "🔍 Acción 11 - Consulta Monto Factura (96 caracteres esperados)"
      echo "  Campo Acción:              2 (${payload:0:2})"
      echo "  Campo ID:                  8 (${payload:2:8})"
      echo "  Campo Fecha (ddmmaaaa):    8 (${payload:10:8})"
      echo "  Campo Hora (hhmmss):       6 (${payload:18:6})"
      echo "  Cadena Comercial:         10 (${payload:24:10})"
      echo "  Tienda:                    5 (${payload:34:5})"
      echo "  Terminal:                 10 (${payload:39:10})"
      echo "  Hora Local:                6 (${payload:49:6})"
      echo "  Fecha Local:               8 (${payload:55:8})"
      echo "  Folio:                    10 (${payload:63:10})"
      echo "  Teléfono:                 10 (${payload:73:10})"
      echo "  CUR:                      13 (${payload:83:13})"
      ;;
    "12")
      echo "🔍 Acción 12 - Respuesta Consulta (124 caracteres esperados)"
      echo "  Campo Acción:              2 (${payload:0:2})"
      echo "  Campo ID:                  8 (${payload:2:8})"
      echo "  Campo Fecha:               8 (${payload:10:8})"
      echo "  Campo Hora:                6 (${payload:18:6})"
      echo "  Cadena Comercial:         10 (${payload:24:10})"
      echo "  Tienda:                    5 (${payload:34:5})"
      echo "  Terminal:                 10 (${payload:39:10})"
      echo "  Hora Local:                6 (${payload:49:6})"
      echo "  Fecha Local:               8 (${payload:55:8})"
      echo "  Folio:                    10 (${payload:63:10})"
      echo "  Teléfono:                 10 (${payload:73:10})"
      echo "  CUR:                      13 (${payload:83:13})"
      echo "  Saldo Estimado:           10 (${payload:96:10})"
      echo "  Saldo Actual:             10 (${payload:106:10})"
      echo "  Código de Respuesta:       2 (${payload:116:2})"
      echo "  Nº Transacción Telcel:     6 (${payload:118:6})"
      ;;
    "13")
      echo "🔍 Acción 13 - Requerimiento de Pago (108 caracteres esperados)"
      echo "  Campo Acción:              2 (${payload:0:2})"
      echo "  Campo ID:                  8 (${payload:2:8})"
      echo "  Campo Fecha:               8 (${payload:10:8})"
      echo "  Campo Hora:                6 (${payload:18:6})"
      echo "  Cadena Comercial:         10 (${payload:24:10})"
      echo "  Tienda:                    5 (${payload:34:5})"
      echo "  Terminal:                 10 (${payload:39:10})"
      echo "  Hora Local:                6 (${payload:49:6})"
      echo "  Fecha Local:               8 (${payload:55:8})"
      echo "  Folio:                    10 (${payload:63:10})"
      echo "  Teléfono:                 10 (${payload:73:10})"
      echo "  CUR:                      13 (${payload:83:13})"
      echo "  Monto:                    10 (${payload:96:10})"
      echo "  Compromiso de Pago:        2 (${payload:106:2})"
      ;;
    "14")
      echo "🔍 Acción 14 - Respuesta a Pago (120 caracteres esperados)"
      echo "  Campo Acción:              2 (${payload:0:2})"
      echo "  Campo ID:                  8 (${payload:2:8})"
      echo "  Campo Fecha:               8 (${payload:10:8})"
      echo "  Campo Hora:                6 (${payload:18:6})"
      echo "  Cadena Comercial:         10 (${payload:24:10})"
      echo "  Tienda:                    5 (${payload:34:5})"
      echo "  Terminal:                 10 (${payload:39:10})"
      echo "  Hora Local:                6 (${payload:49:6})"
      echo "  Fecha Local:               8 (${payload:55:8})"
      echo "  Folio:                    10 (${payload:63:10})"
      echo "  Teléfono:                 10 (${payload:73:10})"
      echo "  CUR:                      13 (${payload:83:13})"
      echo "  Monto:                    10 (${payload:96:10})"
      echo "  Compromiso de Pago:        2 (${payload:106:2})"
      echo "  Código de Respuesta:       2 (${payload:108:2})"
      echo "  Nº Transacción Telcel:     6 (${payload:110:6})"
      ;;
    "96"|"97"|"98"|"99")
      echo "🔍 Acción $accion - Echo (24 caracteres esperados)"
      echo "  Campo Acción:              2 (${payload:0:2})"
      echo "  Campo ID:                  8 (${payload:2:8})"
      echo "  Campo Fecha:               8 (${payload:10:8})"
      echo "  Campo Hora:                6 (${payload:18:6})"
      ;;
    *)
      echo "⚠️ Acción no reconocida: $accion"
      ;;
  esac

  body="${payload:0:${#payload}}"
  echo "📤 Longitud mensaje enviado: ${#body} (esperada: 24)"
  if [ ${#body} -ne 24 ]; then
    echo "❌ Longitud incorrecta en mensaje enviado."
  else
    echo "✅ Longitud correcta en mensaje enviado."
  fi

  local msg=$(printf "\x02%s\x03" "$payload")

  echo "[Acción 96] Longitud: ${#msg} caracteres"
  echo "📡 Enviando ECHO (96DU)..."
  # --- Patch: Enviar por TCP usando exec, capturar y mostrar response ---
  local respuesta=""
  exec 3<> /dev/tcp/$HOST/$PORT
  echo -ne "$msg" >&3
  read -r -t 5 respuesta <&3
  exec 3<&-
  exec 3>&-
  echo "📥 Respuesta recibida desde el servidor TCP: $respuesta"
  echo "🔎 Longitud de respuesta: ${#respuesta}"
  echo "📥 Respuesta recibida: $respuesta"
  echo "📏 Longitud de respuesta: ${#respuesta}"
  # 📨 Log especial requerido
  echo -e "📨 Respuesta recibida (${#respuesta} caracteres): $respuesta"
}

# Acción 98 – Solicitud de Echo (24 caracteres sin STX/ETX)
# Acción:  2 => "98"
# ID:      8 => "DU000001"
# Fecha:   8 => "05072025"
# Hora:    6 => "120000"
# Total: 24 caracteres
send_98du() {
  local fecha=$(date +%d%m%Y)   # 8
  local hora=$(date +%H%M%S)    # 6
  local payload=$(printf "98DU000001%s%s" "$fecha" "$hora")

  clean_payload=$(echo "$payload" | tr -d '\r' | sed -n 's/.*\x02\(.*\)\x03.*/\1/p')
  payload_length=${#payload}
  echo "📦 Payload recibido ($payload_length caracteres): $payload"
  accion="${payload:0:2}"
  case "$accion" in
    "11")
      echo "🔍 Acción 11 - Consulta Monto Factura (96 caracteres esperados)"
      echo "  Campo Acción:              2 (${payload:0:2})"
      echo "  Campo ID:                  8 (${payload:2:8})"
      echo "  Campo Fecha (ddmmaaaa):    8 (${payload:10:8})"
      echo "  Campo Hora:                6 (${payload:18:6})"
      echo "  Cadena Comercial:         10 (${payload:24:10})"
      echo "  Tienda:                    5 (${payload:34:5})"
      echo "  Terminal:                 10 (${payload:39:10})"
      echo "  Hora Local:                6 (${payload:49:6})"
      echo "  Fecha Local:               8 (${payload:55:8})"
      echo "  Folio:                    10 (${payload:63:10})"
      echo "  Teléfono:                 10 (${payload:73:10})"
      echo "  CUR:                      13 (${payload:83:13})"
      ;;
    "12")
      echo "🔍 Acción 12 - Respuesta Consulta (124 caracteres esperados)"
      echo "  Campo Acción:              2 (${payload:0:2})"
      echo "  Campo ID:                  8 (${payload:2:8})"
      echo "  Campo Fecha:               8 (${payload:10:8})"
      echo "  Campo Hora:                6 (${payload:18:6})"
      echo "  Cadena Comercial:         10 (${payload:24:10})"
      echo "  Tienda:                    5 (${payload:34:5})"
      echo "  Terminal:                 10 (${payload:39:10})"
      echo "  Hora Local:                6 (${payload:49:6})"
      echo "  Fecha Local:               8 (${payload:55:8})"
      echo "  Folio:                    10 (${payload:63:10})"
      echo "  Teléfono:                 10 (${payload:73:10})"
      echo "  CUR:                      13 (${payload:83:13})"
      echo "  Saldo Estimado:           10 (${payload:96:10})"
      echo "  Saldo Actual:             10 (${payload:106:10})"
      echo "  Código de Respuesta:       2 (${payload:116:2})"
      echo "  Nº Transacción Telcel:     6 (${payload:118:6})"
      ;;
    "13")
      echo "🔍 Acción 13 - Requerimiento de Pago (108 caracteres esperados)"
      echo "  Campo Acción:              2 (${payload:0:2})"
      echo "  Campo ID:                  8 (${payload:2:8})"
      echo "  Campo Fecha:               8 (${payload:10:8})"
      echo "  Campo Hora:                6 (${payload:18:6})"
      echo "  Cadena Comercial:         10 (${payload:24:10})"
      echo "  Tienda:                    5 (${payload:34:5})"
      echo "  Terminal:                 10 (${payload:39:10})"
      echo "  Hora Local:                6 (${payload:49:6})"
      echo "  Fecha Local:               8 (${payload:55:8})"
      echo "  Folio:                    10 (${payload:63:10})"
      echo "  Teléfono:                 10 (${payload:73:10})"
      echo "  CUR:                      13 (${payload:83:13})"
      echo "  Monto:                    10 (${payload:96:10})"
      echo "  Compromiso de Pago:        2 (${payload:106:2})"
      ;;
    "14")
      echo "🔍 Acción 14 - Respuesta a Pago (120 caracteres esperados)"
      echo "  Campo Acción:              2 (${payload:0:2})"
      echo "  Campo ID:                  8 (${payload:2:8})"
      echo "  Campo Fecha:               8 (${payload:10:8})"
      echo "  Campo Hora:                6 (${payload:18:6})"
      echo "  Cadena Comercial:         10 (${payload:24:10})"
      echo "  Tienda:                    5 (${payload:34:5})"
      echo "  Terminal:                 10 (${payload:39:10})"
      echo "  Hora Local:                6 (${payload:49:6})"
      echo "  Fecha Local:               8 (${payload:55:8})"
      echo "  Folio:                    10 (${payload:63:10})"
      echo "  Teléfono:                 10 (${payload:73:10})"
      echo "  CUR:                      13 (${payload:83:13})"
      echo "  Monto:                    10 (${payload:96:10})"
      echo "  Compromiso de Pago:        2 (${payload:106:2})"
      echo "  Código de Respuesta:       2 (${payload:108:2})"
      echo "  Nº Transacción Telcel:     6 (${payload:110:6})"
      ;;
    "96"|"97"|"98"|"99")
      echo "🔍 Acción $accion - Echo (24 caracteres esperados)"
      echo "  Campo Acción:              2 (${payload:0:2})"
      echo "  Campo ID:                  8 (${payload:2:8})"
      echo "  Campo Fecha:               8 (${payload:10:8})"
      echo "  Campo Hora:                6 (${payload:18:6})"
      ;;
    *)
      echo "⚠️ Acción no reconocida: $accion"
      ;;
  esac

  body="${payload:0:${#payload}}"
  echo "📤 Longitud mensaje enviado: ${#body} (esperada: 24)"
  if [ ${#body} -ne 24 ]; then
    echo "❌ Longitud incorrecta en mensaje enviado."
  else
    echo "✅ Longitud correcta en mensaje enviado."
  fi

  local msg=$(printf "\x02%s\x03" "$payload")

  echo "[Acción 98] Longitud: ${#msg} caracteres"
  echo "📡 Enviando 98DU (inicio)..."
  # --- Patch: Enviar por TCP usando exec, capturar y mostrar response ---
  local respuesta=""
  exec 3<> /dev/tcp/$HOST/$PORT
  echo -ne "$msg" >&3
  read -r -t 5 respuesta <&3
  exec 3<&-
  exec 3>&-
  echo "📥 Respuesta recibida desde el servidor TCP: $respuesta"
  echo "🔎 Longitud de respuesta: ${#respuesta}"
  echo "📥 Respuesta recibida: $respuesta"
  echo "📏 Longitud de respuesta: ${#respuesta}"
  # 📨 Log especial requerido
  echo -e "📨 Respuesta recibida (${#respuesta} caracteres): $respuesta"
}

# Inicio de pruebas
# Acción 98 – Esperado: 24 caracteres
# send_98du

# 🧪 Iniciando pruebas de acción 13DU (Pago de Factura)...
echo -e "\n🧪 Iniciando pruebas de acción 13DU (Pago de Factura)..."
echo "▶️ Código esperado: 00 - Respuesta OK"
# Acción 13 – Esperado: 108 caracteres
send_13du "0704202501" "1234567890"

echo "▶️ Código esperado: 01 - Teléfono o CUR no válidos"
# Acción 13 – Esperado: 108 caracteres
send_13du "0704202502" "1234567891"

echo "▶️ Código esperado: 02 - Destino no disponible"
# Acción 13 – Esperado: 108 caracteres
send_13du "0704202503" "1234567892"

echo "▶️ Código esperado: 04 - Teléfono no susceptible de consultar el saldo"
# Acción 13 – Esperado: 108 caracteres
send_13du "0704202504" "1234567894"

echo "▶️ Código esperado: 06 - Mantenimiento Telcel en curso"
# Acción 13 – Esperado: 108 caracteres
send_13du "0704202505" "1234567896"

echo "▶️ Código esperado: 07 - Tabla de transacciones llena"
# Acción 13 – Esperado: 108 caracteres
send_13du "0704202506" "1234567897"

echo "▶️ Código esperado: 08 - Rechazo por time-out interno"
# Acción 13 – Esperado: 108 caracteres
send_13du "0704202507" "1234567898"

echo "▶️ Código esperado: 10 - Teléfono en Abogados"
# Acción 13 – Esperado: 108 caracteres
send_13du "0704202508" "1234567890"

echo "▶️ Código esperado: 11 - Teléfono sin responsabilidad de pago"
# Acción 13 – Esperado: 108 caracteres
send_13du "0704202509" "1234567891"

echo "▶️ Código esperado: 13 - Autenticación fallida"
# Acción 13 – Esperado: 108 caracteres
send_13du "0704202510" "1234567893"

echo "▶️ Código esperado: 15 - Cuenta no susceptible por contracargos"
# Acción 13 – Esperado: 108 caracteres
send_13du "0704202511" "1234567895"

# 🧪 Iniciando pruebas de acción 11DU (Consulta de monto factura)...
echo -e "\n🧪 Iniciando pruebas de acción 11DU (Consulta de monto factura)..."

echo "▶️ Código esperado: 00 - Respuesta OK"
# Acción 11 – Esperado: 96 caracteres
send_11du "0704202510" "1234567890"

echo "▶️ Código esperado: 01 - Teléfono o CUR no válidos"
# Acción 11 – Esperado: 96 caracteres
send_11du "0704202511" "1234567891"

echo "▶️ Código esperado: 02 - Destino no disponible"
# Acción 11 – Esperado: 96 caracteres
send_11du "0704202512" "1234567892"

echo "▶️ Código esperado: 04 - Teléfono no susceptible de consultar el saldo"
# Acción 11 – Esperado: 96 caracteres
send_11du "0704202513" "1234567894"

echo "▶️ Código esperado: 06 - Mantenimiento Telcel en curso"
# Acción 11 – Esperado: 96 caracteres
send_11du "0704202514" "1234567896"

echo "▶️ Código esperado: 07 - Tabla de transacciones llena"
# Acción 11 – Esperado: 96 caracteres
send_11du "0704202515" "1234567897"

echo "▶️ Código esperado: 08 - Rechazo por time-out interno"
# Acción 11 – Esperado: 96 caracteres
send_11du "0704202516" "1234567898"

echo "▶️ Código esperado: 10 - Teléfono en Abogados"
# Acción 11 – Esperado: 96 caracteres
send_11du "0704202517" "1234567890"

echo "▶️ Código esperado: 11 - Teléfono sin responsabilidad de pago"
# Acción 11 – Esperado: 96 caracteres
send_11du "0704202518" "1234567891"

echo "▶️ Código esperado: 12 - Número de consultas excedidas"
# Acción 11 – Esperado: 96 caracteres
send_11du "0704202519" "1234567892"

echo "▶️ Código esperado: 13 - Autenticación fallida"
# Acción 11 – Esperado: 96 caracteres
send_11du "0704202520" "1234567893"

echo "▶️ Código esperado: 15 - Cuenta no susceptible por contracargos"
# Acción 11 – Esperado: 96 caracteres
send_11du "0704202521" "1234567895"

# Enviar ECHO final
# Acción 96 – Esperado: 24 caracteres
send_echo

echo -e "\n✅ Pruebas completadas. Verifica los logs del mock Telcel para confirmar respuestas."