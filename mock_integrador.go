package main

import (
	"fmt"
	"log"
	"net"
)

func handle13DU(msg string) {
	if len(msg) < 20 {
		fmt.Printf("❌ Error: Mensaje 13DU demasiado corto o mal formado: %s\n", msg)
		return
	}
	// Procesar mensaje 13DU
	// ...
}

func handle11DU(msg string) {
	if len(msg) < 15 {
		fmt.Printf("❌ Error: Mensaje 11DU demasiado corto o mal formado: %s\n", msg)
		return
	}
	// Procesar mensaje 11DU
	// ...
}

func handle96DU(msg string, conn net.Conn) {
	if len(msg) < 18 {
		fmt.Printf("❌ Error: Mensaje 96DU demasiado corto: %s\n", msg)
		return
	}
	transactionID := msg[4:18]
	response := fmt.Sprintf("97DU000001%s", transactionID[8:])
	fullResponse := fmt.Sprintf("%c%s%c", 0x02, response, 0x03)
	conn.Write([]byte(fullResponse))
	log.Printf("📤 Respuesta 97DU enviada: %s", response)
}

func handleConnection(conn net.Conn) {
	defer conn.Close()
	buffer := make([]byte, 1024)
	for {
		n, err := conn.Read(buffer)
		if err != nil {
			log.Println("Error leyendo desde conexión:", err)
			return
		}
		payload := string(buffer[:n])
		if len(payload) < 4 {
			log.Println("Mensaje demasiado corto recibido:", payload)
			continue
		}
		switch payload[:4] {
		case "13DU":
			handle13DU(payload)
		case "11DU":
			handle11DU(payload)
		case "96DU":
			handle96DU(payload, conn)
		default:
			log.Println("Mensaje no reconocido:", payload)
		}
	}
}
