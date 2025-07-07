# Estructura de Payloads Telcel – Acciones 11, 12, 13, 14

## Formato general del mensaje:
- STX (1 byte): Inicio de mensaje (ASCII 2)
- Acción (2): Código de acción: 11, 12, 13, 14
 - ID (8): Identificador compuesto por 2 dígitos de fuente (DU) + 6 de consecutivo. Es numerico creado por Middleware, si es menor a 6 digitos rellena con Ceros.
- Fecha (8): ddmmaaaa
- Hora (6): hhmmss
- Parte Variable (depende de la acción)
- ETX (1 byte): Fin de mensaje (ASCII 3)

**Nota:** Las longitudes totales indicadas incluyen los campos fijos (Acción, DU, Longitud, ID, Fecha, Hora) más la parte variable, y excluyen los bytes STX y ETX.

-------------------------------------------

## Acción 11: Requerimiento de Monto de Factura

| Campo        | Longitud | Descripción                        |
|--------------|----------|------------------------------------|
| Acción       | 2        | Código de acción (11)              |
| ID           | 8        | Fuente (2) + Consecutivo (6)       |
| Fecha        | 8        | ddmmaaaa                           |
| Hora         | 6        | hhmmss                             |
| Cadena Comercial | 10       | Numérico                                 |
| Tienda           | 5        | Numérico                                 |
| Terminal         | 10       | Alfanumérico                             |
| Hora Local       | 6        | hhmmss                                   |
| Fecha Local      | 8        | aaaammdd                                 |
| Folio            | 10       | Numérico                                 |
| Teléfono         | 10       | Numérico                                 |
| CUR              | 13       | Numérico                                 |

Longitud total (sin STX/ETX): 96 caracteres

-------------------------------------------

## Acción 12: Respuesta a Requerimiento de Monto de Factura

| Campo        | Longitud | Descripción                        |
|--------------|----------|------------------------------------|
| Acción       | 2        | Código de acción (12)              |
| ID           | 8        | Fuente (2) + Consecutivo (6)       |
| Fecha        | 8        | ddmmaaaa                           |
| Hora         | 6        | hhmmss                             |
| Cadena Comercial      | 10       | Igual a Acción 11                       |
| Tienda                | 5        | Igual a Acción 11                       |
| Terminal              | 10       | Igual a Acción 11                       |
| Hora Local            | 6        | Igual a Acción 11                       |
| Fecha Local           | 8        | Igual a Acción 11                       |
| Folio                 | 10       | Igual a Acción 11                       |
| Teléfono              | 10       | Igual o devuelto según CUR             |
| CUR                   | 13       | Igual o devuelto según Teléfono        |
| Saldo Estimado        | 10       | Últimos 2 dígitos son decimales        |
| Saldo Actual          | 10       | Últimos 2 dígitos son decimales        |
| Código de Respuesta   | 2        | 00, 01, 02, etc.                        |
| Nº Transacción Telcel | 6        | Numérico con ceros a la izquierda      |

Longitud total (sin STX/ETX): 124 caracteres

-------------------------------------------

## Acción 13: Requerimiento de Pago de Factura

| Campo        | Longitud | Descripción                        |
|--------------|----------|------------------------------------|
| Acción       | 2        | Código de acción (13)              |
| ID           | 8        | Fuente (2) + Consecutivo (6)       |
| Fecha        | 8        | ddmmaaaa                           |
| Hora         | 6        | hhmmss                             |
| Cadena Comercial   | 10       | Numérico                              |
| Tienda             | 5        | Numérico                              |
| Terminal           | 10       | Alfanumérico                          |
| Hora Local         | 6        | hhmmss                                |
| Fecha Local        | 8        | aaaammdd                              |
| Folio              | 10       | Numérico                              |
| Teléfono           | 10       | Numérico                              |
| CUR                | 13       | Numérico                              |
| Monto              | 10       | Últimos 2 dígitos son decimales       |
| Compromiso de Pago | 2        | 10 (efectivo), 11, 12                 |

Longitud total (sin STX/ETX): 108 caracteres

-------------------------------------------

## Acción 14: Respuesta a Requerimiento de Pago de Factura

| Campo        | Longitud | Descripción                        |
|--------------|----------|------------------------------------|
| Acción       | 2        | Código de acción (14)              |
| ID           | 8        | Fuente (2) + Consecutivo (6)       |
| Fecha        | 8        | ddmmaaaa                           |
| Hora         | 6        | hhmmss                             |
| Cadena Comercial      | 10       | Igual a Acción 13                     |
| Tienda                | 5        | Igual a Acción 13                     |
| Terminal              | 10       | Igual a Acción 13                     |
| Hora Local            | 6        | Igual a Acción 13                     |
| Fecha Local           | 8        | Igual a Acción 13                     |
| Folio                 | 10       | Igual a Acción 13                     |
| Teléfono              | 10       | Igual a Acción 13                     |
| CUR                   | 13       | Igual a Acción 13                     |
| Monto                 | 10       | Igual a Acción 13                     |
| Compromiso de Pago    | 2        | Igual a Acción 13                     |
| Código de Respuesta   | 2        | 00, 01, 02, etc.                      |
| Nº Transacción Telcel | 6        | Numérico con ceros a la izquierda     |

Longitud total (sin STX/ETX): 116 caracteres



-------------------------------------------

## Acción 96: Solicitud de Echo (de Telcel a Entidad Externa)

| Campo  | Longitud | Descripción                                           |
|--------|----------|-------------------------------------------------------|
| Acción | 2        | Código de acción (96)                                 |
| ID     | 8        | ID alfanumérico: "DU" (identificador asignado a nosotros) + consecutivo de 6 dígitos |
| Fecha  | 8        | ddmmaaaa                                              |
| Hora   | 6        | hhmmss                                                |

Longitud total (sin STX/ETX): 24 caracteres

-------------------------------------------

## Acción 97: Respuesta a Solicitud de Echo (de Entidad Externa a Telcel)

| Campo  | Longitud | Descripción                                           |
|--------|----------|-------------------------------------------------------|
| Acción | 2        | Código de acción (97)                                 |
| ID     | 8        | Mismo ID recibido en Acción 96 (comienza con 'DU')    |
| Fecha  | 8        | Mismo valor recibido en Acción 96                     |
| Hora   | 6        | Mismo valor recibido en Acción 96                     |

Longitud total (sin STX/ETX): 24 caracteres

-------------------------------------------

## Acción 98: Solicitud de Echo (de Entidad Externa a Telcel)

| Campo  | Longitud | Descripción                                           |
|--------|----------|-------------------------------------------------------|
| Acción | 2        | Código de acción (98)                                 |
| ID     | 8        | ID alfanumérico: "DU" (identificador asignado a nosotros) + consecutivo de 6 dígitos |
| Fecha  | 8        | ddmmaaaa                                              |
| Hora   | 6        | hhmmss                                                |

Longitud total (sin STX/ETX): 24 caracteres

-------------------------------------------

## Acción 99: Respuesta a Solicitud de Echo (de Telcel a Entidad Externa)

| Campo  | Longitud | Descripción                                           |
|--------|----------|-------------------------------------------------------|
| Acción | 2        | Código de acción (99)                                 |
| ID     | 8        | Mismo ID recibido en Acción 98 (comienza con 'DU')    |
| Fecha  | 8        | Mismo valor recibido en Acción 98                     |
| Hora   | 6        | Mismo valor recibido en Acción 98                     |

Longitud total (sin STX/ETX): 24 caracteres

-------------------------------------------

## Resumen de Longitudes Totales por Acción (sin STX/ETX)
Longitud total por acción (suma de campos fijos + parte variable, sin STX/ETX):
```
- Acción 11: 96 caracteres
- Acción 12: 124 caracteres
- Acción 13: 108 caracteres
- Acción 14: 120 caracteres
- Acción 96: 24 caracteres
- Acción 97: 24 caracteres
- Acción 98: 24 caracteres
- Acción 99: 24 caracteres
```

-------------------------------------------

## Ejemplos válidos para Acciones Echo:

Ejemplos válidos para Acción 96:
- \x0296TL00000104072025120000\x03

Ejemplos válidos para Acción 97:
- \x0297TL00000104072025120000\x03

Ejemplos válidos para Acción 98:
- \x0298DU00000104072025120000\x03

Ejemplos válidos para Acción 99:
- \x0299DU00000104072025120000\x03


---

### Significado detallado de los códigos de respuesta

#### Común a Acción 12 y Acción 14:

| Código | Significado                                                                 |
|--------|------------------------------------------------------------------------------|
| 00     | Respuesta OK.                                                                |
| 01     | Teléfono o CUR no válidos.                                                   |
| 02     | Destino no disponible (problemas con WS o DB, no se logró ejecutar WS).     |
| 04     | Teléfono no susceptible de consultar el saldo.                               |
| 06     | Mantenimiento Telcel en curso.                                               |
| 07     | Tabla de transacciones llena.                                                |
| 08     | Rechazo por time-out interno.                                                |
| 10     | Teléfono en Abogados, acudir a un Centro de Atención a Clientes (CAC).      |
| 11     | Teléfono sin responsabilidad de pago, acudir a CAC.                         |
| 13     | Autenticación fallida (cliente, cadena comercial o tienda, según logs).      |
| 15     | Cuenta no susceptible de recibir pagos por contracargos, dirigirse a CAC.    |

#### Exclusivos de Acción 12:

| Código | Significado                                                                 |
|--------|------------------------------------------------------------------------------|
| 12     | Número de consultas de saldo excedidas por parte de la línea pospago.        |

Ejemplos válidos para Acción 11:

Ejemplo 1: \x0211DU001041DE00000112000004072025000000123455667788991234567890123\x03
Ejemplo 2: \x0211DU001041DE00000112050004072025000000123455667788991234567890123\x03

Ejemplos válidos para Acción 12:

Ejemplo 1: \x0212DU001421DE0000011200000407202500000012345566778899123456789012300001234560000123456000000123\x03
Ejemplo 2: \x0212DU001421DE0000011205000407202500000012345566778899123456789012300005678900009876501000456\x03

Ejemplos válidos para Acción 13:

Ejemplo 1: \x0213DU001261DE00000112000004072025000000123455667788991234567890123000010000010\x03
Ejemplo 2: \x0213DU001261DE00000112050004072025000000123455667788991234567890123000050000011\x03

Ejemplos válidos para Acción 14:

Ejemplo 1: \x0214DU001341DE000001120000040720250000001234556677889912345678901230000100000100000123\x03
Ejemplo 2: \x0214DU001341DE000001120500040720250000001234556677889912345678901230000500000120001456\x03

---

## Consideraciones sobre Echos y TPS (Transacciones por Segundo)

Según la especificación del protocolo Telcel:

> “El envío de echos debe realizarse en un rango que va de 20 segundos a 5 minutos, esto depende de las características de carga del Distribuidor, entre mayor TPS, mayor debe ser el tiempo…”

Esto implica lo siguiente:

- Si el sistema procesa pocas transacciones por segundo (TPS), el intervalo entre echos puede ser cercano a los 20 segundos.
- Si el sistema procesa muchas transacciones por segundo, se recomienda aumentar el intervalo hasta 5 minutos para no saturar el canal de comunicación.

### Cálculo de TPS

TPS (Transacciones por Segundo) se calcula dividiendo la cantidad de transacciones enviadas en un período por el número de segundos de ese período.  
Por ejemplo, si en 1 minuto se envían 600 transacciones, el TPS es:  
```
TPS = 600 / 60 = 10
```

### Recomendaciones según el TPS

| TPS estimado | Intervalo sugerido entre echos |
|-------------|-------------------------------|
| 0–1 TPS     | 20–60 segundos                |
| 1–10 TPS    | 1–3 minutos                   |
| 10+ TPS     | 3–5 minutos                   |

### Justificación técnica

El ajuste dinámico del intervalo entre echos permite:
- Cumplir con el requerimiento de Telcel.
- Minimizar sobrecarga innecesaria de mensajes.
- Mantener la conexión activa con un control eficiente.

Este enfoque es consistente con prácticas de monitoreo en sistemas de alta disponibilidad donde la frecuencia de "heartbeats" o "echos" se ajusta en función de la carga (TPS) para evitar congestión y desconexiones erráticas.

---

## Justificación basada en prácticas industriales y estándares

### Prácticas de la industria

**1. Bancos y Switches de Pago (VisaNet, Prosa, Mastercard):**
- Emplean mensajes de "heartbeat" para verificar conectividad entre nodos.
- Ajustan el intervalo de envío dependiendo del volumen de transacciones (TPS).
- Alta carga ➝ menor frecuencia (mayor intervalo); Baja carga ➝ mayor frecuencia (menor intervalo).

**2. Sistemas de Alta Disponibilidad (Kubernetes, RabbitMQ, Redis):**
- Ajustan dinámicamente el "health check" o heartbeat dependiendo de la criticidad del canal y la actividad del sistema.
- Objetivo: evitar congestión y mantener canales activos sin sobrecarga.

**3. Gateways de Pago (Stripe, Adyen, Worldpay):**
- En conexiones persistentes (TCP, WebSocket), emplean intervalos de 20 segundos hasta 5 minutos, según la actividad.

### Estándares relevantes

**📘 ISO/IEC 30170 – Cloud System Heartbeat Mechanism**
- Los mecanismos de heartbeat deben ajustarse a la carga del sistema y criticidad del canal.

**📘 ISO/IEC 27002 – Seguridad de la Información (Sección 12.4)**
- Recomienda ajustar la frecuencia de verificación y monitoreo según el uso del sistema para evitar eventos innecesarios.

**📘 ITU-T X.731 – Fault Management**
- Especifica que el intervalo de heartbeat debe:
  - Ser configurable.
  - Ajustarse a la carga (TPS).
  - Balancear precisión vs. eficiencia de canal.

### Tabla de referencia recomendada

| TPS estimado | Intervalo sugerido entre echos |
|--------------|-------------------------------|
| 0–1 TPS      | 20–60 segundos                |
| 1–10 TPS     | 1–3 minutos                   |
| 10+ TPS      | 3–5 minutos                   |

Esta tabla busca balancear:
- Mantener la conexión activa de manera eficiente.
- No sobrecargar el canal con echos innecesarios.
- Cumplir con lo establecido por Telcel y buenas prácticas internacionales.

---