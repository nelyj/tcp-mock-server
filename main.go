package main

import (
	"fmt"
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
		message := strings.Trim(received, "\x02\x03")
		fmt.Println("📥 Mensaje recibido:", message)

		switch {
		case strings.HasPrefix(message, "97TL"):
			continue

		case strings.HasPrefix(message, "98DU"):
			validatedConnections.Store(remoteIP, true)
			response := generateEchoAction("99", "DU")
			conn.Write([]byte(response))
			fmt.Println("📤 Mensaje enviado (raw):", response)
			fmt.Println("✅ Echo enviado y conexión validada para", remoteIP)

		case strings.HasPrefix(message, "11DU"):
			fmt.Println("🔎 Largo del mensaje:", len(message))
			val, ok := validatedConnections.Load(remoteIP)
			isValidated, _ := val.(bool)
			if !ok || !isValidated {
				fmt.Println("🚫 Conexión no validada con Echo desde", remoteIP)
				continue
			}
			transactionID := getTransactionID(message)
			fmt.Println("🔑 transactionID:", transactionID)
			phone := message[73:83]
			fmt.Println("📱 phone:", phone)
			responseCode := phone[8:]
			fmt.Println("📟 responseCode:", responseCode)
			response := buildTelcelResponseMessageBillInquiry(responseCode, transactionID)
			waitOneSecond()
			conn.Write([]byte(response))
			fmt.Println("📤 Mensaje enviado (raw):", response)
			fmt.Println("📤 Respuesta enviada:", strings.Trim(response, "\x02\x03"))

		case strings.HasPrefix(message, "13DU"):
			fmt.Println("🔎 Largo del mensaje:", len(message))
			val, ok := validatedConnections.Load(remoteIP)
			isValidated, _ := val.(bool)
			if !ok || !isValidated {
				fmt.Println("🚫 Conexión no validada con Echo desde", remoteIP)
				continue
			}
			transactionID := getTransactionID(message)
			fmt.Println("🔑 transactionID:", transactionID)
			phone := message[73:83]
			fmt.Println("📱 phone:", phone)
			responseCode := phone[8:]
			fmt.Println("📟 responseCode:", responseCode)
			response := buildTelcelResponseMessageBillPayment(responseCode, transactionID)
			waitOneSecond()
			conn.Write([]byte(response))
			fmt.Println("📤 Mensaje enviado (raw):", response)
			fmt.Println("📤 Respuesta enviada:", strings.Trim(response, "\x02\x03"))

		case strings.HasPrefix(message, "01DU"):
			val, ok := validatedConnections.Load(remoteIP)
			isValidated, _ := val.(bool)
			if !ok || !isValidated {
				fmt.Println("🚫 Conexión no validada con Echo desde", remoteIP)
				continue
			}
			transactionID := getTransactionID(message)
			response := buildTelcelResponseMessageAirTime("00", transactionID)
			waitOneSecond()
			conn.Write([]byte(response))
			fmt.Println("📤 Mensaje enviado (raw):", response)
			fmt.Println("📤 Respuesta enviada:", strings.Trim(response, "\x02\x03"))

		case strings.HasPrefix(message, "21DU"):
			val, ok := validatedConnections.Load(remoteIP)
			isValidated, _ := val.(bool)
			if !ok || !isValidated {
				fmt.Println("🚫 Conexión no validada con Echo desde", remoteIP)
				continue
			}
			transactionID := getTransactionID(message)
			response := buildTelcelResponseMessageServiceSales("00", transactionID)
			waitOneSecond()
			conn.Write([]byte(response))
			fmt.Println("📤 Mensaje enviado (raw):", response)
			fmt.Println("📤 Respuesta enviada:", strings.Trim(response, "\x02\x03"))

		default:
			waitOneSecond()
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
			_, err := conn.Write([]byte(generateEchoAction("96", "TL")))
			if err != nil {
				fmt.Println("❌ cannot_send_echo", err)
				return
			}
			fmt.Println("✅ Echo enviado")
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

func buildTelcelResponseMessageBillInquiry(responseCode, transactionID string) string {
	var sb strings.Builder
	sb.WriteString("\x02")
	sb.WriteString("12DU000001")
	sb.WriteString(time.Now().Format("02012006"))
	sb.WriteString(time.Now().Format("150405"))
	sb.WriteString("1234567890")
	sb.WriteString("00012")
	sb.WriteString("TERM001234")
	sb.WriteString(time.Now().Format("150405"))
	sb.WriteString(time.Now().Format("20060102"))
	sb.WriteString(normalizeStringLength(transactionID, 10))
	sb.WriteString("5551234567")
	sb.WriteString("1234567890123")
	sb.WriteString("0000012000")
	sb.WriteString("0000013000")
	sb.WriteString(normalizeStringLength(responseCode, 2))
	sb.WriteString("000123")
	sb.WriteString("\x03")
	return sb.String()
}

func buildTelcelResponseMessageBillPayment(responseCode, transactionID string) string {
	var sb strings.Builder
	sb.WriteString("\x02")
	sb.WriteString("14DU000001")
	sb.WriteString(time.Now().Format("02012006"))
	sb.WriteString(time.Now().Format("150405"))
	sb.WriteString("1234567890")
	sb.WriteString("00012")
	sb.WriteString("TERM001234")
	sb.WriteString(time.Now().Format("150405"))
	sb.WriteString(time.Now().Format("20060102"))
	sb.WriteString(normalizeStringLength(transactionID, 10))
	sb.WriteString("5551234567")
	sb.WriteString("1234567890123")
	sb.WriteString("0000010000")
	sb.WriteString("01")
	sb.WriteString(normalizeStringLength(responseCode, 2))
	sb.WriteString("000123")
	sb.WriteString("\x03")
	return sb.String()
}

func buildTelcelResponseMessageAirTime(responseCode, transactionID string) string {
	var sb strings.Builder
	sb.WriteString("\x02")
	sb.WriteString("02DU000001")
	sb.WriteString(time.Now().Format("20060102"))
	sb.WriteString(time.Now().Format("150405"))
	sb.WriteString("CADENA1234")
	sb.WriteString("T0012")
	sb.WriteString("TERM001234")
	sb.WriteString(time.Now().Format("150405"))
	sb.WriteString(time.Now().Format("20060102"))
	sb.WriteString(normalizeStringLength(transactionID, 10))
	sb.WriteString("5551234567")
	sb.WriteString("0000010000")
	sb.WriteString(normalizeStringLength(responseCode, 2))
	sb.WriteString("654321")
	sb.WriteString("\x03")
	return sb.String()
}

func buildTelcelResponseMessageServiceSales(responseCode, transactionID string) string {
	var sb strings.Builder
	sb.WriteString("\x02")
	sb.WriteString("22DU000001")
	sb.WriteString(time.Now().Format("02012006"))
	sb.WriteString(time.Now().Format("150405"))
	sb.WriteString("CADENA1234")
	sb.WriteString("T0012")
	sb.WriteString("TERM001234")
	sb.WriteString(time.Now().Format("150405"))
	sb.WriteString(time.Now().Format("20060102"))
	sb.WriteString(normalizeStringLength(transactionID, 10))
	sb.WriteString("5551234567")
	sb.WriteString("0000010000")
	sb.WriteString("ABCDEF1234")
	sb.WriteString(normalizeStringLength(responseCode, 2))
	sb.WriteString("000000")
	sb.WriteString("\x03")
	return sb.String()
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
