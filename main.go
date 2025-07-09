package main

import (
	"fmt"
	"net"
	"os"
	"strings"
	"time"
)

type DynamicFields struct {
	Telefono        string
	CUR             string
	Monto           string
	Compromiso      string
	Tienda          string
	Terminal        string
	CadenaComercial string
}

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
		fmt.Printf("received_raw: %q\n", received)

		message := string(received)
		message = strings.Trim(message, "\x02\x03")
		fmt.Println("parsed_message:", message)
		if strings.HasPrefix(message, "97TL") {
			continue
		}

		if strings.HasPrefix(message, "98DU") {
			response := generateEchoAction("99", "DU")
			fmt.Printf("sending_response: %q\n", response)
			_, err := conn.Write([]byte(response))
			if err != nil {
				fmt.Println("error sending message:", err)
				break
			}
			continue
		}

		if strings.HasPrefix(message, "11DU") {
			fmt.Printf("11DU received length: %d\n", len(message))
			if len(message) < 96 {
				fmt.Printf("Invalid message length for 11DU (%d), expected 96\n", len(message))
				return
			}
			transactionID := getTransactionID(message)
			phone := message[73:83]
			responseCode := phone[8:]
			fmt.Println("responseCode 11DU:", responseCode)
			tienda := message[34:39]
			terminal := message[39:49]
			cadenaComercial := message[24:34]
			fields := DynamicFields{
				Telefono:        message[73:83],
				CUR:             message[83:96],
				Tienda:          tienda,
				Terminal:        terminal,
				CadenaComercial: cadenaComercial,
			}
			msgResponse := buildTelcelResponseMessageBillInquiry(responseCode, transactionID, fields)
			fmt.Printf("sending_response: %q\n", msgResponse)
			waitOneSecond()
			conn.Write([]byte(msgResponse))
			continue
		}
		if strings.HasPrefix(message, "13DU") {
			transactionID := getTransactionID(message)
			phone := message[73:83]
			responseCode := phone[8:] // last 2 digits
			fmt.Println("responseCode 13DU:", responseCode)
			tienda := message[34:39]
			terminal := message[39:49]
			cadenaComercial := message[24:34]
			fields := DynamicFields{
				Telefono:        message[73:83],
				CUR:             message[83:96],
				Monto:           message[96:106],
				Compromiso:      message[106:108],
				Tienda:          tienda,
				Terminal:        terminal,
				CadenaComercial: cadenaComercial,
			}
			msgResponse := buildTelcelResponseMessageBillPayment(responseCode, transactionID, fields)
			fmt.Printf("sending_response: %q\n", msgResponse)
			waitOneSecond()
			conn.Write([]byte(msgResponse))
			continue
		}

		if strings.HasPrefix(message, "01DU") {
			transactionID := getTransactionID(message)
			tienda := message[42:47]
			terminal := message[47:57]
			cadenaComercial := message[24:34]
			fields := DynamicFields{
				Telefono:        message[73:83],
				CUR:             message[83:96],
				Monto:           message[96:106],
				Compromiso:      message[106:108],
				Tienda:          tienda,
				Terminal:        terminal,
				CadenaComercial: cadenaComercial,
			}
			msgResponse := buildTelcelResponseMessageAirTime("00", transactionID, fields)
			fmt.Printf("sending_response: %q\n", msgResponse)
			waitOneSecond()
			conn.Write([]byte(msgResponse))
			continue
		}

		if strings.HasPrefix(message, "21DU") {
			transactionID := getTransactionID(message)
			tienda := message[42:47]
			terminal := message[47:57]
			cadenaComercial := message[32:42]
			fields := DynamicFields{
				Telefono:        message[73:83],
				CUR:             message[83:96],
				Monto:           message[96:106],
				Compromiso:      message[106:108],
				Tienda:          tienda,
				Terminal:        terminal,
				CadenaComercial: cadenaComercial,
			}
			msgResponse := buildTelcelResponseMessageServiceSales("00", transactionID, fields)
			fmt.Printf("sending_response: %q\n", msgResponse)
			waitOneSecond()
			conn.Write([]byte(msgResponse))
			continue
		}

		fmt.Printf("echoing_back: %q\n", received)
		waitOneSecond()
		conn.Write([]byte(received))
	}
}

func buildTelcelResponseMessageBillPayment(responseCode, transactionID string, fields DynamicFields) string {
	var sb strings.Builder

	// ──────── CABECERA ────────
	sb.WriteString("\x02")                        // STX
	sb.WriteString("14")                          // Acción 14 (Pago de Factura)
	sb.WriteString("DU")                          // Categoría
	sb.WriteString("000001")                      // Consecutivo (6 chars)
	sb.WriteString(time.Now().Format("02012006")) // Fecha (ddmmaaaa)
	sb.WriteString(time.Now().Format("150405"))   // Hora (hhmmss)

	// ──────── CUERPO DEL MENSAJE ────────
	sb.WriteString(fields.CadenaComercial)                   // Cadena Comercial (10 dígitos)
	sb.WriteString(fields.Tienda)                            // Tienda (5 dígitos)
	sb.WriteString(fields.Terminal)                          // Terminal o Caja (10 alfanum)
	sb.WriteString(time.Now().Format("150405"))              // Hora local (hhmmss)
	sb.WriteString(time.Now().Format("20060102"))            // Fecha local (aaaammdd)
	sb.WriteString(normalizeStringLength(transactionID, 10)) // Folio (10 dígitos)
	sb.WriteString(fields.Telefono)                          // Teléfono (10 dígitos)
	sb.WriteString(fields.CUR)                               // CUR (13 dígitos)
	sb.WriteString(fields.Monto)                             // Monto (10 dígitos, incluye decimales)
	sb.WriteString(fields.Compromiso)                        // Compromiso de pago (2 dígitos)
	sb.WriteString(normalizeStringLength(responseCode, 2))   // Código de respuesta (2 dígitos)
	sb.WriteString("000123")                                 // Transacción Telcel (6 dígitos)

	sb.WriteString("\x03") // ETX
	return sb.String()
}

func buildTelcelResponseMessageServiceSales(responseCode, transactionID string, fields DynamicFields) string {

	var sb strings.Builder

	// ──────── FIXED PART ────────
	sb.WriteString("\x02")                        // STX
	sb.WriteString("22")                          // Acción 22 (Respuesta de Servicio)
	sb.WriteString("DU")                          // Categoría
	sb.WriteString("000001")                      // Consecutivo (6 chars)
	sb.WriteString(time.Now().Format("02012006")) // Fecha (ddmmaaaa)
	sb.WriteString(time.Now().Format("150405"))   // Hora (hhmmss)

	// ──────── VARIABLE PART ────────
	sb.WriteString(fields.CadenaComercial)                   // Cadena Comercial (10 chars)
	sb.WriteString(fields.Tienda)                            // Tienda (5 chars)
	sb.WriteString(fields.Terminal)                          // Terminal/Caja (10 chars)
	sb.WriteString(time.Now().Format("150405"))              // Hora local (hhmmss)
	sb.WriteString(time.Now().Format("20060102"))            // Fecha local (aaaammdd)
	sb.WriteString(normalizeStringLength(transactionID, 10)) // Folio (10 chars)
	sb.WriteString(fields.Telefono)                          // Teléfono (10 chars)
	sb.WriteString(fields.Monto)                             // Monto (10 chars: 100.00)
	sb.WriteString("ABCDEF1234")                             // ID Producto (10 chars)
	sb.WriteString(normalizeStringLength(responseCode, 2))   // Código de respuesta (2 chars)
	sb.WriteString("000000")                                 // Transacción Telcel (6 chars, default)

	sb.WriteString("\x03") // ETX
	return sb.String()
}

func buildTelcelResponseMessageAirTime(responseCode, transactionID string, fields DynamicFields) string {
	var sb strings.Builder

	// ──────── FIXED PART ────────
	sb.WriteString("\x02")                        // STX
	sb.WriteString("02")                          // Acción 02 (Abono Tiempo Aire)
	sb.WriteString("DU")                          // Categoría
	sb.WriteString("000001")                      // Consecutivo (6 chars)
	sb.WriteString(time.Now().Format("20060102")) // Fecha local (aaaammdd)
	sb.WriteString(time.Now().Format("150405"))   // Hora local (hhmmss)

	// ──────── VARIABLE PART ────────
	sb.WriteString(fields.CadenaComercial)                   // Cadena Comercial (10 chars)
	sb.WriteString(fields.Tienda)                            // Tienda (5 chars)
	sb.WriteString(fields.Terminal)                          // Terminal/Caja (10 chars)
	sb.WriteString(time.Now().Format("150405"))              // Hora local (hhmmss)
	sb.WriteString(time.Now().Format("20060102"))            // Fecha local (aaaammdd)
	sb.WriteString(normalizeStringLength(transactionID, 10)) // Folio (10 chars)
	sb.WriteString(fields.Telefono)                          // Teléfono (10 chars)
	sb.WriteString(fields.Monto)                             // Monto (10 chars: 100.00)
	sb.WriteString(normalizeStringLength(responseCode, 2))   // Código de respuesta (2 chars)
	sb.WriteString("654321")                                 // Transacción Telcel (6 chars)

	sb.WriteString("\x03") // ETX
	return sb.String()
}

func buildTelcelResponseMessageBillInquiry(responseCode, transactionID string, fields DynamicFields) string {
	var sb strings.Builder

	// ──────── CABECERA ────────
	sb.WriteString("\x02")                        // STX
	sb.WriteString("12")                          // Acción 12 (Respuesta a Requerimiento de Monto Factura)
	sb.WriteString("DU")                          // Categoría
	sb.WriteString("000001")                      // Consecutivo
	sb.WriteString(time.Now().Format("02012006")) // Fecha (ddmmaaaa)
	sb.WriteString(time.Now().Format("150405"))   // Hora (hhmmss)

	// ──────── CUERPO DEL MENSAJE ────────
	sb.WriteString(fields.CadenaComercial)                   // Cadena Comercial (10)
	sb.WriteString(fields.Tienda)                            // Tienda (5)
	sb.WriteString(fields.Terminal)                          // Terminal (10)
	sb.WriteString(time.Now().Format("150405"))              // Hora local (6)
	sb.WriteString(time.Now().Format("20060102"))            // Fecha local (8)
	sb.WriteString(normalizeStringLength(transactionID, 10)) // Folio (10)
	sb.WriteString(fields.Telefono)                          // Teléfono (10)
	sb.WriteString(fields.CUR)                               // CUR (13)
	sb.WriteString("0000012000")                             // Saldo Estimado (10)
	sb.WriteString("0000013000")                             // Saldo Actual (10)
	sb.WriteString(normalizeStringLength(responseCode, 2))   // Código de respuesta (2)
	sb.WriteString("000123")                                 // Transacción Telcel (6)

	sb.WriteString("\x03") // ETX
	return sb.String()
}

func generateEchoAction(actions string, sourceIdentifier string) string {
	now := time.Now()
	dateFormat := os.Getenv("TELCEL_FECHA_FORMAT")
	if dateFormat == "" {
		dateFormat = "02012006"
	}
	hourFormat := os.Getenv("TELCEL_HORA_FORMAT")
	if hourFormat == "" {
		hourFormat = "150405"
	}
	start := "\x02"
	end := "\x03"
	formattedConsecutive := fmt.Sprintf("%06d", 1)
	return fmt.Sprintf("%s%s%s%s%s%s%s", start, actions, sourceIdentifier, formattedConsecutive, now.Format(dateFormat), now.Format(hourFormat), end)
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
