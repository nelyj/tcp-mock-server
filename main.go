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
		done := make(chan struct{})
		go SendEchos(conn, done)
		go handleConnection(conn, done)
	}
}

func handleConnection(conn net.Conn, done chan struct{}) {
	defer conn.Close()
	fmt.Println("new_connection", conn.RemoteAddr())

	buffer := make([]byte, 1024)

	for {
		// Deadline de lectura: 60 segundos
		conn.SetReadDeadline(time.Now().Add(60 * time.Second))

		n, err := conn.Read(buffer)
		if err != nil {
			if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
				fmt.Println("⏳ Read timeout, esperando nuevo mensaje...")
				continue
			}
			fmt.Println("connection close o error reading:", err)
			break
		}

		received := string(buffer[:n])
		message := strings.Trim(received, "\x02\x03")

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
			responseCode := phone[8:]
			msgResponse := buildTelcelResponseMessageBillInquiry(responseCode, transactionID)
			waitOneSecond()
			conn.Write([]byte(msgResponse))
			continue
		}
		if strings.HasPrefix(message, "13DU") {
			fmt.Println(message)
			transactionID := getTransactionID(message)
			phone := message[73:83]
			responseCode := phone[8:]
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

func SendEchos(conn net.Conn, done <-chan struct{}) {
	for {
		time.Sleep(1 * time.Minute)
		_, err := conn.Write([]byte(generateEchoAction("96", "TL")))
		if err != nil {
			fmt.Println("cannot_send_echo", err)
			break
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
