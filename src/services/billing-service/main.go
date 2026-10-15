package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"
)

type AMILectura struct {
	NIU              string  `json:"niu"`
	MedidorSerie     string  `json:"medidor_serie"`
	TimestampLectura string  `json:"timestamp_lectura"`
	Intervalo        string  `json:"intervalo"`
	KwhImportados    float64 `json:"kwh_importados"`
	KwhExportados    float64 `json:"kwh_exportados"`
	TensionVoltios   float64 `json:"tension_voltios"`
}

type FacturaGenerada struct {
	InvoiceID      string  `json:"invoice_id"`
	NIU            string  `json:"niu"`
	Periodo        string  `json:"periodo"`
	TotalCOP       float64 `json:"total_cop"`
	KwhNetos       float64 `json:"kwh_netos"`
	CreditoExc1Kwh float64 `json:"credito_exc1_kwh"`
	Status         string  `json:"status"`
}

type InvoiceRequest struct {
	AccountID string  `json:"account_id"`
	Total     float64 `json:"total"`
}

type InvoiceResponse struct {
	InvoiceID     string `json:"invoice_id"`
	Status        string `json:"status"`
	PaymentStatus string `json:"payment_status"`
}

type PaymentRequest struct {
	AccountID string  `json:"account_id"`
	Amount    float64 `json:"amount"`
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}

// eventsHandler procesa CloudEvents recibidos desde Knative Event Mesh (trigger-billing-ami)
func eventsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	ceType := r.Header.Get("Ce-Type")
	ceID := r.Header.Get("Ce-Id")
	ceSource := r.Header.Get("Ce-Source")
	log.Printf("[BILLING EVENT] CloudEvent recibido: ID=%s Type=%s Source=%s", ceID, ceType, ceSource)

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading request body", http.StatusBadRequest)
		return
	}

	if ceType == "com.voltera.ami.lectura_registrada" || ceType == "" {
		var lectura AMILectura
		if err := json.Unmarshal(body, &lectura); err != nil {
			log.Printf("[BILLING WARN] Error deserializando lectura AMI: %v (raw: %s)", err, string(body))
			http.Error(w, "Invalid AMI reading JSON", http.StatusBadRequest)
			return
		}

		// Calculo de Netting y Tarifa CREG (Resolucion CREG 101-072 de 2025 / CREG 174)
		// Costo unitario referencial: 850 COP/kWh
		costoUnitario := 850.0
		netKwh := lectura.KwhImportados - lectura.KwhExportados
		var totalCOP float64
		if netKwh > 0 {
			totalCOP = netKwh * costoUnitario
		} else {
			// Cargo minimo de red / comercializacion
			totalCOP = 5000.0
		}

		invoiceID := fmt.Sprintf("INV-%d", time.Now().UnixNano()/1000000)
		periodo := time.Now().Format("2006-01")

		factura := FacturaGenerada{
			InvoiceID:      invoiceID,
			NIU:            lectura.NIU,
			Periodo:        periodo,
			TotalCOP:       totalCOP,
			KwhNetos:       netKwh,
			CreditoExc1Kwh: lectura.KwhExportados,
			Status:         "ISSUED",
		}

		log.Printf("[BILLING] Factura generada con exito: %s para NIU %s | Total: $%.2f COP (Neto: %.2f kWh)",
			invoiceID, lectura.NIU, totalCOP, netKwh)

		// Knative Eventing Reply Pattern:
		// Responder con un nuevo CloudEvent (com.voltera.billing.factura_generada)
		// para que el Broker lo distribuya automaticamente a payment-service.
		respBody, err := json.Marshal(factura)
		if err != nil {
			http.Error(w, "Error serializing invoice", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Ce-Specversion", "1.0")
		w.Header().Set("Ce-Type", "com.voltera.billing.factura_generada")
		w.Header().Set("Ce-Source", "//cloud/billing/engine")
		w.Header().Set("Ce-Id", invoiceID)
		w.Header().Set("Ce-Time", time.Now().UTC().Format(time.RFC3339))
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write(respBody)
		return
	}

	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"ignored","reason":"unsupported event type"}`))
}

// generateInvoiceHandler atiende peticiones REST sincronas directas
func generateInvoiceHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req InvoiceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	log.Printf("Generando factura sincrona para cuenta %s por valor %.2f", req.AccountID, req.Total)

	// Invocacion directa con Istio Service Mesh (mTLS automatico)
	paymentURL := getEnv("PAYMENT_URL", "http://payment-service:8081/process")
	paymentReq := PaymentRequest{
		AccountID: req.AccountID,
		Amount:    req.Total,
	}
	payload, _ := json.Marshal(paymentReq)

	resp, err := http.Post(paymentURL, "application/json", bytes.NewBuffer(payload))
	paymentStatus := "FAILED"
	if err != nil {
		log.Printf("Error conectando a payment-service (%s): %v", paymentURL, err)
	} else {
		defer resp.Body.Close()
		body, _ := io.ReadAll(resp.Body)
		log.Printf("Respuesta de payment-service: %s", string(body))
		if resp.StatusCode == http.StatusOK {
			paymentStatus = "SUCCESS"
		}
	}

	invoiceID := fmt.Sprintf("INV-%d", time.Now().UnixNano()/1000000)
	res := InvoiceResponse{
		InvoiceID:     invoiceID,
		Status:        "ISSUED",
		PaymentStatus: paymentStatus,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(res)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "healthy",
		"service": "billing-service",
	})
}

func main() {
	port := getEnv("PORT", "8080")

	// Endpoint sincrono REST
	http.HandleFunc("/invoice", generateInvoiceHandler)

	// Endpoint asincrono Knative Event Mesh (CloudEvents)
	http.HandleFunc("/events", eventsHandler)

	// Probe de salud para Kubernetes
	http.HandleFunc("/health", healthHandler)

	log.Printf("Billing Service (Facturacion) iniciando en el puerto :%s...", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Error iniciando servidor: %v", err)
	}
}
