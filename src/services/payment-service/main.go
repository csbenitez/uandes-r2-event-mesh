package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"
)

type PaymentRequest struct {
	AccountID string  `json:"account_id"`
	Amount    float64 `json:"amount"`
}

type PaymentResponse struct {
	Status        string `json:"status"`
	TransactionID string `json:"transaction_id"`
	Message       string `json:"message"`
}

type FacturaEvent struct {
	InvoiceID      string  `json:"invoice_id"`
	NIU            string  `json:"niu"`
	Periodo        string  `json:"periodo"`
	TotalCOP       float64 `json:"total_cop"`
	KwhNetos       float64 `json:"kwh_netos"`
	CreditoExc1Kwh float64 `json:"credito_exc1_kwh"`
	Status         string  `json:"status"`
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}

// eventsHandler procesa CloudEvents recibidos desde Knative Event Mesh (trigger-payment-invoice)
func eventsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	ceType := r.Header.Get("Ce-Type")
	ceID := r.Header.Get("Ce-Id")
	ceSource := r.Header.Get("Ce-Source")
	log.Printf("[PAYMENT EVENT] CloudEvent recibido: ID=%s Type=%s Source=%s", ceID, ceType, ceSource)

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading request body", http.StatusBadRequest)
		return
	}

	if ceType == "com.voltera.billing.factura_generada" || ceType == "" {
		var factura FacturaEvent
		if err := json.Unmarshal(body, &factura); err != nil {
			log.Printf("[PAYMENT WARN] Error deserializando factura: %v (raw: %s)", err, string(body))
			http.Error(w, "Invalid invoice JSON", http.StatusBadRequest)
			return
		}

		txnID := fmt.Sprintf("TXN-MESH-%d", time.Now().UnixNano()/1000000)
		log.Printf("[PAYMENT] Cobro y dispersion exitosa para Factura %s (NIU %s) por valor $%.2f COP | Txn: %s",
			factura.InvoiceID, factura.NIU, factura.TotalCOP, txnID)

		res := map[string]interface{}{
			"status":         "SUCCESS",
			"transaction_id": txnID,
			"invoice_id":     factura.InvoiceID,
			"niu":            factura.NIU,
			"amount_charged": factura.TotalCOP,
			"message":        "Pago y dispersion procesados satisfactoriamente via Event Mesh",
			"timestamp":      time.Now().UTC().Format(time.RFC3339),
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(res)
		return
	}

	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"ignored","reason":"unsupported event type"}`))
}

// processPaymentHandler atiende llamadas sincronas directas
func processPaymentHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req PaymentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	txnID := fmt.Sprintf("TXN-%d", time.Now().UnixNano()/1000000)
	log.Printf("[PAYMENT SYNC] Recibida solicitud de pago para cuenta %s por valor %.2f | Txn: %s",
		req.AccountID, req.Amount, txnID)

	res := PaymentResponse{
		Status:        "SUCCESS",
		TransactionID: txnID,
		Message:       fmt.Sprintf("Pago de %.2f procesado correctamente", req.Amount),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(res)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "healthy",
		"service": "payment-service",
	})
}

func main() {
	port := getEnv("PORT", "8081")

	// Endpoint sincrono REST
	http.HandleFunc("/process", processPaymentHandler)

	// Endpoint asincrono Knative Event Mesh (CloudEvents)
	http.HandleFunc("/events", eventsHandler)

	// Probe de salud para Kubernetes
	http.HandleFunc("/health", healthHandler)

	log.Printf("Payment Service (Pagos) iniciando en el puerto :%s...", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Error iniciando servidor: %v", err)
	}
}
