package main

import (
	"fmt"
	"net"
	"strings"
	"time"
)

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
		go SendEchos(conn)
		go handleConnection(conn)
	}
}

func handleConnection(conn net.Conn) {
	defer conn.Close()
	fmt.Println("new_connection", conn.RemoteAddr())

	buffer := make([]byte, 1024)

	for {
		n, err := conn.Read(buffer)
		if err != nil {
			fmt.Println("connection close o error reading:", err)
			break
		}

		received := string(buffer[:n])

		message := string(received)
		message = strings.Trim(message, "\x02\x03")
		if strings.HasPrefix(message, "97TL") {
			continue
		}

		if strings.HasPrefix(message, "98DU") {
			_, err := conn.Write([]byte(generateEchoAction("99", "DU")))
			if err != nil {
				fmt.Println("error sending message:", err)
				break
			}
			continue
		}

		if strings.HasPrefix(message, "11DU") {
			transactionID := getTransactionID(message)
			phone := message[73:83]
			responseCode := phone[8:] // last 2 digits

			msgResponse := buildTelcelResponseMessageBillInquiry(responseCode, transactionID)
			waitOneSecond()
			conn.Write([]byte(msgResponse))
			continue
		}

		if strings.HasPrefix(message, "13DU") {
			fmt.Println(message)
			transactionID := getTransactionID(message)
			phone := message[73:83]
			responseCode := phone[8:] // last 2 digits

			msgResponse := buildTelcelResponseMessageBillPayment(responseCode, transactionID)
			waitOneSecond()
			conn.Write([]byte(msgResponse))
			continue
		}

		if strings.HasPrefix(message, "01DU") {
			transactionID := getTransactionID(message)
			waitOneSecond()
			conn.Write([]byte(buildTelcelResponseMessageAirTime("00", transactionID)))
			continue
		}

		if strings.HasPrefix(message, "21DU") {
			transactionID := getTransactionID(message)
			waitOneSecond()
			conn.Write([]byte(buildTelcelResponseMessageServiceSales("00", transactionID)))
			continue
		}

		waitOneSecond()
		conn.Write([]byte(received))
	}
}

func buildTelcelResponseMessageBillPayment(responseCode, transactionID string) string {
	var sb strings.Builder

	// ──────── CABECERA ────────
	sb.WriteString("\x02")                        // STX
	sb.WriteString("14")                          // Acción 14 (Pago de Factura)
	sb.WriteString("DU")                          // Categoría
	sb.WriteString("000001")                      // Consecutivo (6 chars)
	sb.WriteString(time.Now().Format("02012006")) // Fecha (ddmmaaaa)
	sb.WriteString(time.Now().Format("150405"))   // Hora (hhmmss)

	// ──────── CUERPO DEL MENSAJE ────────
	sb.WriteString("1234567890")                             // Cadena Comercial (10 dígitos)
	sb.WriteString("00012")                                  // Tienda (5 dígitos)
	sb.WriteString("TERM001234")                             // Terminal o Caja (10 alfanum)
	sb.WriteString(time.Now().Format("150405"))              // Hora local (hhmmss)
	sb.WriteString(time.Now().Format("20060102"))            // Fecha local (aaaammdd)
	sb.WriteString(normalizeStringLength(transactionID, 10)) // Folio (10 dígitos)
	sb.WriteString("5551234567")                             // Teléfono (10 dígitos)
	sb.WriteString("1234567890123")                          // CUR (13 dígitos)
	sb.WriteString("0000010000")                             // Monto (10 dígitos, incluye decimales)
	sb.WriteString("01")                                     // Compromiso de pago (2 dígitos)
	sb.WriteString(normalizeStringLength(responseCode, 2))   // Código de respuesta (2 dígitos)
	sb.WriteString("000123")                                 // Transacción Telcel (6 dígitos)

	sb.WriteString("\x03") // ETX
	return sb.String()
}

func buildTelcelResponseMessageServiceSales(responseCode, transactionID string) string {

	var sb strings.Builder

	// ──────── FIXED PART ────────
	sb.WriteString("\x02")                        // STX
	sb.WriteString("22")                          // Acción 22 (Respuesta de Servicio)
	sb.WriteString("DU")                          // Categoría
	sb.WriteString("000001")                      // Consecutivo (6 chars)
	sb.WriteString(time.Now().Format("02012006")) // Fecha (ddmmaaaa)
	sb.WriteString(time.Now().Format("150405"))   // Hora (hhmmss)

	// ──────── VARIABLE PART ────────
	sb.WriteString("CADENA1234")                             // Cadena Comercial (10 chars)
	sb.WriteString("T0012")                                  // Tienda (5 chars)
	sb.WriteString("TERM001234")                             // Terminal/Caja (10 chars)
	sb.WriteString(time.Now().Format("150405"))              // Hora local (hhmmss)
	sb.WriteString(time.Now().Format("20060102"))            // Fecha local (aaaammdd)
	sb.WriteString(normalizeStringLength(transactionID, 10)) // Folio (10 chars)
	sb.WriteString("5551234567")                             // Teléfono (10 chars)
	sb.WriteString("0000010000")                             // Monto (10 chars: 100.00)
	sb.WriteString("ABCDEF1234")                             // ID Producto (10 chars)
	sb.WriteString(normalizeStringLength(responseCode, 2))   // Código de respuesta (2 chars)
	sb.WriteString("000000")                                 // Transacción Telcel (6 chars, default)

	sb.WriteString("\x03") // ETX
	return sb.String()
}

func buildTelcelResponseMessageAirTime(responseCode, transactionID string) string {
	var sb strings.Builder

	// ──────── FIXED PART ────────
	sb.WriteString("\x02")                        // STX
	sb.WriteString("02")                          // Acción 02 (Abono Tiempo Aire)
	sb.WriteString("DU")                          // Categoría
	sb.WriteString("000001")                      // Consecutivo (6 chars)
	sb.WriteString(time.Now().Format("20060102")) // Fecha local (aaaammdd)
	sb.WriteString(time.Now().Format("150405"))   // Hora local (hhmmss)

	// ──────── VARIABLE PART ────────
	sb.WriteString("CADENA1234")                             // Cadena Comercial (10 chars)
	sb.WriteString("T0012")                                  // Tienda (5 chars)
	sb.WriteString("TERM001234")                             // Terminal/Caja (10 chars)
	sb.WriteString(time.Now().Format("150405"))              // Hora local (hhmmss)
	sb.WriteString(time.Now().Format("20060102"))            // Fecha local (aaaammdd)
	sb.WriteString(normalizeStringLength(transactionID, 10)) // Folio (10 chars)
	sb.WriteString("5551234567")                             // Teléfono (10 chars)
	sb.WriteString("0000010000")                             // Monto (10 chars: 100.00)
	sb.WriteString(normalizeStringLength(responseCode, 2))   // Código de respuesta (2 chars)
	sb.WriteString("654321")                                 // Transacción Telcel (6 chars)

	sb.WriteString("\x03") // ETX
	return sb.String()
}

func buildTelcelResponseMessageBillInquiry(responseCode, transactionID string) string {
	var sb strings.Builder

	// ──────── CABECERA ────────
	sb.WriteString("\x02")                        // STX
	sb.WriteString("12")                          // Acción 12 (Respuesta a Requerimiento de Monto Factura)
	sb.WriteString("DU")                          // Categoría
	sb.WriteString("000001")                      // Consecutivo
	sb.WriteString(time.Now().Format("02012006")) // Fecha (ddmmaaaa)
	sb.WriteString(time.Now().Format("150405"))   // Hora (hhmmss)

	// ──────── CUERPO DEL MENSAJE ────────
	sb.WriteString("1234567890")                             // Cadena Comercial (10)
	sb.WriteString("00012")                                  // Tienda (5)
	sb.WriteString("TERM001234")                             // Terminal (10)
	sb.WriteString(time.Now().Format("150405"))              // Hora local (6)
	sb.WriteString(time.Now().Format("20060102"))            // Fecha local (8)
	sb.WriteString(normalizeStringLength(transactionID, 10)) // Folio (10)
	sb.WriteString("5551234567")                             // Teléfono (10)
	sb.WriteString("1234567890123")                          // CUR (13)
	sb.WriteString("0000012000")                             // Saldo Estimado (10)
	sb.WriteString("0000013000")                             // Saldo Actual (10)
	sb.WriteString(normalizeStringLength(responseCode, 2))   // Código de respuesta (2)
	sb.WriteString("000123")                                 // Transacción Telcel (6)

	sb.WriteString("\x03") // ETX
	return sb.String()
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

func SendEchos(conn net.Conn) {
	for {
		time.Sleep(1 * time.Minute)
		_, err := conn.Write([]byte(generateEchoAction("96", "TL")))
		if err != nil {
			fmt.Println("cannot_send_echo", err)
			break
		}
	}
}

func normalizeStringLength(s string, length int) string {
	if len(s) >= length {
		return s[:length]
	}
	return fmt.Sprintf("%0*s", length, s)
}

func getTransactionID(msg string) string {
	if len(msg) < 74 {
		return ""
	}
	return msg[63:73]
}

func waitOneSecond() {
	time.Sleep(1 * time.Second)
}
