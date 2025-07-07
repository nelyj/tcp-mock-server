package main

import (
	"fmt"
	"log"
	"net"
	"strings"
	"sync"
	"time"
)

var activeConnections sync.Map
var validatedConnections sync.Map

func main() {
	host := ""
	port := "9000"

	listener, err := net.Listen("tcp", net.JoinHostPort(host, port))
	if err != nil {
		fmt.Println("Error to start server:", err)
		return
	}
	defer listener.Close()
	fmt.Println("Mock TCP listen", host, "port", port)

	for {
		conn, err := listener.Accept()
		if err != nil {
			fmt.Println("Error to Accept connection:", err)
			continue
		}
		done := make(chan struct{})
		remoteIP := strings.Split(conn.RemoteAddr().String(), ":")[0]
		if _, loaded := activeConnections.LoadOrStore(remoteIP, struct{}{}); !loaded {
			go SendEchos(conn, done, remoteIP)
		} else {
			fmt.Println("🔁 Ya existe conexión activa para IP", remoteIP)
		}
		go handleConnection(conn, done)
	}
}

func handleConnection(conn net.Conn, done chan struct{}) {
	defer func() {
		fmt.Println("🔒 Cerrando conexión con", conn.RemoteAddr())
		remoteIP := strings.Split(conn.RemoteAddr().String(), ":")[0]
		activeConnections.Delete(remoteIP)
		validatedConnections.Delete(remoteIP)
		conn.Close()
		close(done)
	}()

	fmt.Println("new_connection", conn.RemoteAddr())
	buffer := make([]byte, 1024)

	remoteIP := strings.Split(conn.RemoteAddr().String(), ":")[0]
	log.Printf("Connection from %s", remoteIP)

	for {
		conn.SetReadDeadline(time.Now().Add(3 * time.Minute))
		n, err := conn.Read(buffer)
		if err != nil {
			if err.Error() == "EOF" {
				fmt.Println("📴 Conexión cerrada por el cliente")
			} else if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
				fmt.Println("⏳ Read timeout, esperando nuevo mensaje...")
				continue
			} else {
				fmt.Println("❌ Error en lectura:", err)
			}
			break
		}

		received := string(buffer[:n])
		fmt.Printf("📦 Raw bytes: % x\n", buffer[:n])
		message := strings.Trim(received, "\x02\x03")
		if len(message) < 4 {
			fmt.Println("❌ Mensaje demasiado corto para evaluar case:", message)
			continue
		}
		messageType := message[0:4]
		fmt.Println("📥 Mensaje recibido:", message)
		fmt.Println("🧪 Evaluando case:", messageType)

		switch {
		case strings.HasPrefix(message, "97TL"):
			fmt.Println("✅ Respuesta recibida a echo 96TL (97TL), conexión activa.")
			continue

		case strings.HasPrefix(message, "11DU"):
			fmt.Println("🔎 Longitud de solicitud recibida:", len(message), "caracteres")
			if len(message) != 96 {
				fmt.Printf("❌ Mensaje 11DU con longitud incorrecta: %d caracteres (esperado: 96)\n", len(message))
				continue
			}
			// Parse fields according to the 11DU structure
			// Referencia: Acción 11: 96 caracteres
			//  0-3:  4  Acción + DU + consecutivo (11DUxxxx)
			//  4-11: 8  Fecha ddmmaaaa
			// 12-17: 6  Hora hhmmss
			// 18-27: 10 Cadena Comercial
			// 28-32: 5  Tienda
			// 33-42: 10 Terminal
			// 43-48: 6  Hora Local
			// 49-56: 8  Fecha Local
			// 57-66: 10 Folio
			// 67-76: 10 Teléfono
			// 77-89: 13 CUR
			transactionID := message[57:67]
			telefono := message[67:77]
			cur := message[77:90]
			responseCode := telefono[len(telefono)-2:]
			fmt.Printf("🔑 transactionID: %s | 📱 telefono: %s | CUR: %s | 📟 responseCode: %s\n", transactionID, telefono, cur, responseCode)
			// La longitud esperada es 96
			response := buildTelcelResponseMessageBillInquiry(responseCode, transactionID, message)
			waitOneSecond()
			// Imprime el mensaje de respuesta al igual que en 14DU
			fmt.Printf("📤 Mensaje de respuesta a enviar: %s\n", response)
			payload := strings.Trim(response, "\x02\x03")
			fmt.Printf("📥 Payload recibido (%d caracteres): %s\n", len(payload), payload)
			conn.Write([]byte(response))
			fmt.Printf("📤 Mensaje enviado (raw): %s\n", response)
			fmt.Printf("📤 Respuesta enviada: %s\n", payload)

		case strings.HasPrefix(message, "13DU"):
			fmt.Println("🔎 Longitud de solicitud recibida:", len(message), "caracteres")
			if len(message) != 108 {
				fmt.Printf("❌ Mensaje 13DU con longitud incorrecta: %d caracteres (esperado: 108)\n", len(message))
				continue
			}
			// Parse fields according to the 13DU structure
			idAccion := "14"
			id := message[2:10]
			fecha := message[10:18]
			hora := message[18:24]
			cadena := message[24:34]
			tienda := message[34:39]
			terminal := message[39:49]
			horaLocal := message[49:55]
			fechaLocal := message[55:63]
			folio := message[63:73]
			telefono := message[73:83]
			cur := message[83:96]
			monto := message[96:106]
			compromisoPago := message[106:108]
			responseCode := ""
			if len(telefono) >= 2 {
				responseCode = telefono[len(telefono)-2:]
			}
			// Asegura formato y longitudes
			cadenaFmt := fmt.Sprintf("%-10s", strings.TrimSpace(cadena))
			tiendaFmt := fmt.Sprintf("%-5s", strings.TrimSpace(tienda))
			terminalFmt := fmt.Sprintf("%-10s", terminal)
			horaLocalFmt := fmt.Sprintf("%06s", strings.TrimSpace(horaLocal))
			fechaLocalFmt := fmt.Sprintf("%08s", strings.TrimSpace(fechaLocal))
			folioFmt := fmt.Sprintf("%010s", strings.TrimSpace(folio))
			telefonoFmt := fmt.Sprintf("%010s", strings.TrimSpace(telefono))
			curFmt := fmt.Sprintf("%-13s", strings.TrimSpace(cur))
			montoFmt := fmt.Sprintf("%010s", strings.TrimSpace(monto))
			compromisoPagoFmt := fmt.Sprintf("%02s", strings.TrimSpace(compromisoPago))
			responseCodeFmt := normalizeStringLength(responseCode, 2)
			numeroTxTelcel := "000123"
			// Construcción exacta del payload de respuesta (Acción 14), con campos de longitud precisa
			payload := fmt.Sprintf("%s%s%08s%06s%-10s%-5s%-10s%06s%08s%010s%010s%-13s%010s%02s%02s%06s",
				idAccion,          // Acción: 2
				id,                // ID: 8
				fecha,             // Fecha: 8
				hora,              // Hora: 6
				cadenaFmt,         // Cadena Comercial: 10
				tiendaFmt,         // Tienda: 5
				terminalFmt,       // Terminal: 10
				horaLocalFmt,      // Hora Local: 6
				fechaLocalFmt,     // Fecha Local: 8
				folioFmt,          // Folio: 10
				telefonoFmt,       // Teléfono: 10
				curFmt,            // CUR: 13
				montoFmt,          // Monto: 10
				compromisoPagoFmt, // Compromiso de Pago: 2
				responseCodeFmt,   // Código de Respuesta: 2
				numeroTxTelcel,    // Nº Transacción Telcel: 6
			)
			if len(payload) > 116 {
				payload = payload[:116]
			}
			if len(payload) != 116 {
				fmt.Printf("❌ Acción 13 respuesta: longitud incorrecta: %d (esperado: 116)\n", len(payload))
			}
			responseBody := "\x02" + payload + "\x03"
			// Imprime los campos de la respuesta 14 antes del mensaje final
			fmt.Println("🧩 Campos de respuesta 14:")
			fmt.Printf("  Acción:                %s (%d)\n", idAccion, len(idAccion))
			fmt.Printf("  ID:                    %s (%d)\n", id, len(id))
			fmt.Printf("  Fecha:                 %s (%d)\n", fecha, len(fecha))
			fmt.Printf("  Hora:                  %s (%d)\n", hora, len(hora))
			fmt.Printf("  Cadena Comercial:      %s (%d)\n", cadenaFmt, len(cadenaFmt))
			fmt.Printf("  Tienda:                %s (%d)\n", tiendaFmt, len(tiendaFmt))
			fmt.Printf("  Terminal:              %s (%d)\n", terminalFmt, len(terminalFmt))
			fmt.Printf("  Hora Local:            %s (%d)\n", horaLocalFmt, len(horaLocalFmt))
			fmt.Printf("  Fecha Local:           %s (%d)\n", fechaLocalFmt, len(fechaLocalFmt))
			fmt.Printf("  Folio:                 %s (%d)\n", folioFmt, len(folioFmt))
			fmt.Printf("  Teléfono:              %s (%d)\n", telefonoFmt, len(telefonoFmt))
			fmt.Printf("  CUR:                   %s (%d)\n", curFmt, len(curFmt))
			fmt.Printf("  Monto:                 %s (%d)\n", montoFmt, len(montoFmt))
			fmt.Printf("  Compromiso de Pago:    %s (%d)\n", compromisoPagoFmt, len(compromisoPagoFmt))
			fmt.Printf("  Código de Respuesta:   %s (%d)\n", responseCodeFmt, len(responseCodeFmt))
			fmt.Printf("  Número Tx Telcel:      %s (%d)\n", numeroTxTelcel, len(numeroTxTelcel))
			fmt.Printf("📤 Respuesta %s (len=%d): %s\n", idAccion, len(responseBody)-2, payload)
			waitOneSecond()
			fmt.Println("Mensaje de respuesta a enviar:", responseBody)
			payloadToPrint := strings.Trim(responseBody, "\x02\x03")
			fmt.Printf("📦 Payload recibido (%d caracteres): %s\n", len(payloadToPrint), payloadToPrint)
			conn.Write([]byte(responseBody))
			fmt.Println("📤 Mensaje enviado (raw):", responseBody)
			fmt.Println("📤 Respuesta enviada:", strings.Trim(responseBody, "\x02\x03"))

		case strings.HasPrefix(message, "98DU"):
			fmt.Println("🔎 Mensaje tipo 98DU recibido")
			// Para echo 98DU, responder con 99DU con mismos campos (Acción, ID, Fecha, Hora)
			if len(message) < 24 {
				fmt.Println("❌ Mensaje 98DU demasiado corto para responder")
				continue
			}
			action := "99"
			id := message[2:10]
			fecha := message[10:18]
			hora := message[18:24]
			payload := fmt.Sprintf("%-2s%-8s%-8s%-6s", action, id, fecha, hora)
			// Asegura longitud 24
			if len(payload) > 24 {
				payload = payload[:24]
			}
			if len(payload) != 24 {
				fmt.Printf("❌ Acción 99 respuesta: longitud incorrecta: %d (esperado: 24)\n", len(payload))
			}
			responseBody := "\x02" + payload + "\x03"
			fmt.Printf("📤 Respuesta %s (len=%d): %s\n", action, len(responseBody)-2, payload)
			waitOneSecond()
			fmt.Println("Mensaje de respuesta a enviar:", responseBody)
			// Log payload before sending (without STX/ETX)
			payloadToPrint := strings.Trim(responseBody, "\x02\x03")
			fmt.Printf("📦 Payload recibido (%d caracteres): %s\n", len(payloadToPrint), payloadToPrint)
			_, err := conn.Write([]byte(responseBody))
			if err != nil {
				fmt.Println("❌ Error enviando respuesta 99DU:", err)
			} else {
				fmt.Println("📤 Respuesta 99DU enviada (Echo)")
			}

		case strings.HasPrefix(message, "96DU"):
			fmt.Println("🔎 Mensaje tipo 96DU recibido - Respondiendo con 97DU")
			if len(message) < 24 {
				fmt.Println("❌ Mensaje 96DU demasiado corto para responder")
				continue
			}
			action := "97"
			id := message[2:10]
			fecha := message[10:18]
			hora := message[18:24]
			payload := fmt.Sprintf("%-2s%-8s%-8s%-6s", action, id, fecha, hora)
			// Asegura longitud 24
			if len(payload) > 24 {
				payload = payload[:24]
			}
			if len(payload) != 24 {
				fmt.Printf("❌ Acción 97 respuesta: longitud incorrecta: %d (esperado: 24)\n", len(payload))
			}
			responseBody := "\x02" + payload + "\x03"
			fmt.Printf("📤 Respuesta %s (len=%d): %s\n", action, len(responseBody)-2, payload)
			waitOneSecond()
			fmt.Println("Mensaje de respuesta a enviar:", responseBody)
			// Log payload before sending (without STX/ETX)
			payloadToPrint := strings.Trim(responseBody, "\x02\x03")
			fmt.Printf("📦 Payload recibido (%d caracteres): %s\n", len(payloadToPrint), payloadToPrint)
			_, err := conn.Write([]byte(responseBody))
			if err != nil {
				fmt.Println("❌ Error enviando respuesta 97DU:", err)
			} else {
				fmt.Println("📤 Respuesta 97DU enviada (Echo)")
			}

		default:
			log.Printf("❌ No matching handler found for case: %s", messageType)
			waitOneSecond()
			payloadToPrint := strings.Trim(received, "\x02\x03")
			fmt.Printf("📦 Payload recibido (%d caracteres): %s\n", len(payloadToPrint), payloadToPrint)
			conn.Write([]byte(received))
			fmt.Println("📤 Eco enviado tal cual (sin parsing)")
		}
	}
}

func SendEchos(conn net.Conn, done <-chan struct{}, remoteIP string) {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()
	defer activeConnections.Delete(remoteIP)

	for {
		select {
		case <-done:
			fmt.Println("🔁 Echo detenido: conexión cerrada")
			return
		case <-ticker.C:
			echo := generateEchoAction("96", "TL")
			_, err := conn.Write([]byte(echo))
			if err != nil {
				fmt.Println("❌ cannot_send_echo", err)
				return
			}
			fmt.Printf("📤 Echo enviado (raw): %s\n", echo)
		}
	}
}

func generateEchoAction(actions string, sourceIdentifier string) string {
	now := time.Now()
	start := "\x02"
	end := "\x03"
	dateFormat := now.Format("20060102")
	hourFormat := now.Format("150405")
	formattedConsecutive := fmt.Sprintf("%06d", 1)
	return fmt.Sprintf("%s%s%s%s%s%s%s", start, actions, sourceIdentifier, formattedConsecutive, dateFormat, hourFormat, end)
}

// Construye la respuesta para acción 12 (Requerimiento de Monto de Factura)
// Recibe responseCode, transactionID y el mensaje original para tomar los campos originales.
func buildTelcelResponseMessageBillInquiry(responseCode, transactionID string, originalMsg string) string {
	// Extraer campos de la petición original 11DU
	//  0-3:   4  Acción + DU + consecutivo (11DUxxxx)
	//  4-11:  8  Fecha ddmmaaaa
	// 12-17:  6  Hora hhmmss
	// 18-27: 10 Cadena Comercial
	// 28-32:  5 Tienda
	// 33-42: 10 Terminal
	// 43-48:  6 Hora Local
	// 49-56:  8 Fecha Local
	// 57-66: 10 Folio
	// 67-76: 10 Teléfono
	// 77-89: 13 CUR
	cadenaComercial := fmt.Sprintf("%010s", strings.TrimSpace(originalMsg[18:28]))
	tienda := fmt.Sprintf("%05s", strings.TrimSpace(originalMsg[28:33]))
	terminal := fmt.Sprintf("%-10s", strings.TrimSpace(originalMsg[33:43]))
	horaLocal := fmt.Sprintf("%06s", strings.TrimSpace(originalMsg[43:49]))
	fechaLocal := fmt.Sprintf("%08s", strings.TrimSpace(originalMsg[49:57]))
	folio := fmt.Sprintf("%010s", strings.TrimSpace(originalMsg[57:67]))
	telefono := fmt.Sprintf("%010s", strings.TrimSpace(originalMsg[67:77]))
	cur := fmt.Sprintf("%013s", strings.TrimSpace(originalMsg[77:90]))
	// Respuesta ejemplo:
	// Acción(2) + ID(8) + Fecha(8) + Hora(6) + Cadena(10) + Tienda(5) + Terminal(10) + HoraLocal(6) + FechaLocal(8) + Folio(10) + Teléfono(10) + CUR(13) + SaldoEst(10) + SaldoAct(10) + CodResp(2) + NumTxTelcel(6)
	var sb strings.Builder
	sb.WriteString("\x02")
	sb.WriteString("12DU000001")                           // Acción(2)+ID(8)
	sb.WriteString(originalMsg[4:12])                      // Fecha(8) ddmmaaaa
	sb.WriteString(originalMsg[12:18])                     // Hora(6) hhmmss
	sb.WriteString(cadenaComercial)                        // 10
	sb.WriteString(tienda)                                 // 5
	sb.WriteString(terminal)                               // 10
	sb.WriteString(horaLocal)                              // 6
	sb.WriteString(fechaLocal)                             // 8
	sb.WriteString(folio)                                  // 10
	sb.WriteString(telefono)                               // 10
	sb.WriteString(cur)                                    // 13
	sb.WriteString("0000012000")                           // Saldo Estimado (10)
	sb.WriteString("0000013000")                           // Saldo Actual (10)
	sb.WriteString(normalizeStringLength(responseCode, 2)) // Código de Respuesta (2)
	sb.WriteString("000123")                               // Nº Transacción Telcel (6)
	sb.WriteString("\x03")
	payload := sb.String()
	validateLength("12", payload, 124)
	// Log longitud
	fmt.Printf("📨 Longitud de respuesta enviada: %d caracteres\n", len(payload)-2)
	return payload
}

// Construye la respuesta para acción 14 (Pago de Factura)
// Recibe responseCode, transactionID y el mensaje original para tomar los campos originales.
func buildTelcelResponseMessageBillPayment(responseCode, transactionID string, originalMsg string) string {
	// Extraer campos de la petición original 13DU
	//  0-3:   4  Acción + DU + consecutivo (13DUxxxx)
	//  4-11:  8  Fecha ddmmaaaa
	// 12-17:  6  Hora hhmmss
	// 18-27: 10 Cadena Comercial
	// 28-32:  5 Tienda
	// 33-42: 10 Terminal
	// 43-48:  6 Hora Local
	// 49-56:  8 Fecha Local
	// 57-66: 10 Folio
	// 67-76: 10 Teléfono
	// 77-89: 13 CUR
	// 90-99: 10 Monto
	// 100-101: 2 Compromiso de Pago
	cadenaComercial := fmt.Sprintf("%010s", strings.TrimSpace(originalMsg[18:28]))
	tienda := fmt.Sprintf("%05s", strings.TrimSpace(originalMsg[28:33]))
	terminal := fmt.Sprintf("%-10s", strings.TrimSpace(originalMsg[33:43]))
	horaLocal := fmt.Sprintf("%06s", strings.TrimSpace(originalMsg[43:49]))
	fechaLocal := fmt.Sprintf("%08s", strings.TrimSpace(originalMsg[49:57]))
	folio := fmt.Sprintf("%010s", strings.TrimSpace(originalMsg[57:67]))
	telefono := fmt.Sprintf("%010s", strings.TrimSpace(originalMsg[67:77]))
	cur := fmt.Sprintf("%013s", strings.TrimSpace(originalMsg[77:90]))
	monto := fmt.Sprintf("%010s", strings.TrimSpace(originalMsg[90:100]))
	compromisoPago := fmt.Sprintf("%02s", strings.TrimSpace(originalMsg[100:102]))
	codAutenticacion := normalizeStringLength(responseCode, 2)
	// Construcción del mensaje de respuesta, comentada campo por campo:
	accion := "14"                                                      // 2 - Acción (ej. "14")
	id := "DU000001"                                                    // 8 - ID de la transacción (mismo que en la solicitud)
	fecha := originalMsg[4:12]                                          // 8 - Fecha (ddmmaaaa)
	hora := originalMsg[12:18]                                          // 6 - Hora (hhmmss)
	cadena := cadenaComercial                                           // 10 - Cadena comercial
	tienda_ := tienda                                                   // 5 - Tienda
	terminal_ := terminal                                               // 10 - Terminal
	horaLocal_ := horaLocal                                             // 6 - Hora local (hhmmss)
	fechaLocal_ := fechaLocal                                           // 8 - Fecha local (aaaammdd)
	folio_ := folio                                                     // 10 - Folio (ej. txid)
	telefono_ := telefono                                               // 10 - Teléfono
	cur_ := cur                                                         // 13 - CUR
	monto_ := monto                                                     // 10 - Monto (ej. "0000100000")
	fechaCompromiso := compromisoPago                                   // 2 - Fecha compromiso de pago (aaaammdd)
	referencia := codAutenticacion + "000123"[:8-len(codAutenticacion)] // 10 - Número de referencia (aquí, codAutenticacion+relleno)
	// Uso del formato solicitado, comentado línea por línea:
	response := "" +
		accion + // 2 - Acción (ej. "14")
		id + // 8 - ID de la transacción (mismo que en la solicitud)
		fecha + // 8 - Fecha (ddmmaaaa)
		hora + // 6 - Hora (hhmmss)
		cadena + // 10 - Cadena comercial
		tienda_ + // 5 - Tienda
		terminal_ + // 10 - Terminal
		codAutenticacion + // 2 - Código de autenticación (ej. "AL")
		horaLocal_ + // 6 - Hora local (hhmmss)
		fechaLocal_ + // 8 - Fecha local (aaaammdd)
		folio_ + // 10 - Folio (ej. txid)
		telefono_ + // 10 - Teléfono
		cur_ + // 13 - CUR
		monto_ + // 10 - Monto (ej. "0000100000")
		fechaCompromiso + // 8 - Fecha compromiso de pago (aaaammdd) [aquí 2, pero para compatibilidad]
		referencia // 10 - Número de referencia
	// Log de longitud de respuesta:
	log.Printf("📏 Longitud de respuesta construida: %d (esperada: 116)", len(response))
	// Añade STX/ETX
	payload := "\x02" + response + "\x03"
	validateLength("14", payload, 116)
	fmt.Printf("📨 Longitud de respuesta enviada: %d caracteres\n", len(payload)-2)
	return payload
}

func buildTelcelResponseMessageAirTime(responseCode, transactionID string) string {
	var sb strings.Builder
	sb.WriteString("\x02")
	sb.WriteString("02DU000001")
	sb.WriteString(time.Now().Format("20060102"))
	sb.WriteString(time.Now().Format("150405"))
	sb.WriteString(fmt.Sprintf("%010s", "CADENA1234"))
	sb.WriteString(fmt.Sprintf("%05s", "T0012"))
	sb.WriteString(fmt.Sprintf("%-10s", "TERM001234"))
	sb.WriteString(time.Now().Format("150405"))
	sb.WriteString(time.Now().Format("20060102"))
	sb.WriteString(fmt.Sprintf("%010s", normalizeStringLength(transactionID, 10)))
	sb.WriteString(fmt.Sprintf("%010s", "5551234567"))
	sb.WriteString(fmt.Sprintf("%010s", "0000010000"))
	sb.WriteString(normalizeStringLength(responseCode, 2))
	sb.WriteString(fmt.Sprintf("%06s", "654321"))
	sb.WriteString("\x03")
	payload := sb.String()
	validateLength("11", payload, 96)
	return payload
}

func buildTelcelResponseMessageServiceSales(responseCode, transactionID string) string {
	var sb strings.Builder
	sb.WriteString("\x02")
	sb.WriteString("22DU000001")
	sb.WriteString(time.Now().Format("02012006"))
	sb.WriteString(time.Now().Format("150405"))
	sb.WriteString(fmt.Sprintf("%010s", "CADENA1234"))
	sb.WriteString(fmt.Sprintf("%05s", "T0012"))
	sb.WriteString(fmt.Sprintf("%-10s", "TERM001234"))
	sb.WriteString(time.Now().Format("150405"))
	sb.WriteString(time.Now().Format("20060102"))
	sb.WriteString(fmt.Sprintf("%010s", normalizeStringLength(transactionID, 10)))
	sb.WriteString(fmt.Sprintf("%010s", "5551234567"))
	sb.WriteString(fmt.Sprintf("%010s", "0000010000"))
	sb.WriteString(fmt.Sprintf("%010s", "ABCDEF1234"))
	sb.WriteString(normalizeStringLength(responseCode, 2))
	sb.WriteString(fmt.Sprintf("%06s", "000000"))
	sb.WriteString("\x03")
	payload := sb.String()
	validateLength("12", payload, 124)
	return payload
}

func buildTelcelResponseMessage99DU(timestamp string) string {
	var sb strings.Builder
	sb.WriteString("\x02")
	sb.WriteString("99DU000001")
	if len(timestamp) >= 8 {
		// timestamp format YYYYMMDDHHMMSS expected length 14
		if len(timestamp) >= 14 {
			sb.WriteString(timestamp[6:8]) // DDMM swapped to MMDD? but keeping as is for now
			sb.WriteString(timestamp[4:6]) // MM
			sb.WriteString(timestamp[0:4]) // YYYY
		} else {
			sb.WriteString(time.Now().Format("02012006"))
		}
	} else {
		sb.WriteString(time.Now().Format("02012006"))
	}
	if len(timestamp) >= 14 {
		sb.WriteString(timestamp[8:14])
	} else {
		sb.WriteString(time.Now().Format("150405"))
	}
	sb.WriteString("RESPUESTA99DU")
	sb.WriteString("000000")
	sb.WriteString("\x03")
	return sb.String()
}

// buildTelcelResponseMessage97DU is obsolete (now handled inline)

func normalizeStringLength(s string, length int) string {
	if len(s) >= length {
		return s[:length]
	}
	return fmt.Sprintf("%0*s", length, s)
}

func getTransactionID(msg string) string {
	if len(msg) < 74 {
		fmt.Printf("❌ Mensaje muy corto para extraer transactionID (len=%d): [%s]\n", len(msg), msg)
		return ""
	}
	return msg[63:73]
}

func waitOneSecond() {
	time.Sleep(1 * time.Second)
}

// validateLength verifica que la longitud del payload (sin STX/ETX) sea la esperada para la acción
func validateLength(action string, payload string, expected int) {
	actual := len(payload) - 2 // excluye STX y ETX
	if actual == expected {
		fmt.Printf("✅ Acción %s: Longitud correcta (%d bytes)\n", action, actual)
	} else {
		fmt.Printf("❌ Acción %s: Longitud incorrecta: %d (esperado: %d)\n", action, actual, expected)
	}
}
