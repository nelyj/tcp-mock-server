# Telcel TCP Mock Server

Este proyecto simula un servidor TCP que responde a los mensajes del protocolo Telcel (`Pago de Factura`, `Tiempo Aire`, `Echo`, etc.), y responde con mensajes formateados como Telcel.

===================================
🖥 Cómo probarlo desde consola
===================================

1. Conéctate al servidor usando netcat:

  nc <host> 9000

  Reemplaza <host> con tu dominio público de Railway o "localhost" si lo corres local.

===================================
📡 Casos de uso disponibles
===================================

▶ 1. Echo Test

Mensaje a enviar:
\x0298DU00000120250627170000\x03

Resultado esperado:
  El servidor responde con \x0299DU... (Echo response simulado).

-----------------------------------

▶ 2. Pago de Factura (13DU)

Mensaje de prueba:
\x0213DU00000120250627170000...<relleno hasta byte 83>...5551234590\x03

  Nota: el número en bytes 73-83 debe terminar con dos dígitos (por ejemplo: 90) que serán usados como código de respuesta.

Resultado esperado:
  Respuesta comienza con \x0214DU... e incluye:
  - Código de respuesta = últimos 2 dígitos del número
  - Monto simulado
  - Teléfono y CUR fijos

-----------------------------------

▶ 3. Tiempo Aire (01DU)

Mensaje de prueba:
\x0201DU00000120250627170000TX1234567890\x03

Resultado esperado:
  Respuesta con \x0202DU... (acción 02) con código de respuesta 00.

-----------------------------------

▶ 4. Venta de Servicio (21DU)

Mensaje de prueba:
\x0221DU00000120250627170000SRV1234567890\x03

Resultado esperado:
  Respuesta con \x0222DU... incluyendo ID producto, monto simulado y respuesta 00.

===================================
🛠 Cómo generar los mensajes desde Bash
===================================

# Echo
echo -ne "\x0298DU000001$(date +%Y%m%d%H%M%S)\x03" | nc <host> 9000

# Pago de factura (teléfono termina en 90)
echo -ne "\x0213DU000001$(date +%Y%m%d%H%M%S)$(printf 'X%.0s' {1..60})5551234590\x03" | nc <host> 9000

# Tiempo aire
echo -ne "\x0201DU000001$(date +%Y%m%d%H%M%S)TX1234567890\x03" | nc <host> 9000

# Venta servicio
echo -ne "\x0221DU000001$(date +%Y%m%d%H%M%S)SRV1234567890\x03" | nc <host> 9000

===================================
📜 Script automatizado: test_telcel_mock.sh
===================================

Guarda el siguiente contenido en un archivo llamado `test_telcel_mock.sh`:

-----------------------------------------------------
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
RELLENO=$(printf 'X%.0s' {1..60})
send_message "pago" "\x0213DU000001${timestamp}${RELLENO}5551234590\x03"

echo -e "\n🔄 Testing Tiempo Aire (01DU)..."
send_message "tiempoaire" "\x0201DU000001${timestamp}TX1234567890\x03"

echo -e "\n🔄 Testing Venta de Servicio (21DU)..."
send_message "servicio" "\x0221DU000001${timestamp}SRV1234567890\x03"

echo -e "\n✅ Pruebas completadas contra $HOST:$PORT"
-----------------------------------------------------

Luego, hazlo ejecutable:

chmod +x test_telcel_mock.sh

Y ejecútalo así:

./test_telcel_mock.sh localhost 9000
# o
./test_telcel_mock.sh mi-servidor.railway.app 9000

Esto generará:
- response_echo.txt
- response_pago.txt
- response_tiempoaire.txt
- response_servicio.txt