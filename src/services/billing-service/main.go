package main

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
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
	CreatedAt      string  `json:"created_at"`
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

// Estructuras y cliente para observabilidad OpenTelemetry / Zipkin
type TraceContext struct {
	TraceID  string
	SpanID   string
	ParentID string
}

type ZipkinEndpoint struct {
	ServiceName string `json:"serviceName"`
}

type ZipkinSpan struct {
	TraceID       string            `json:"traceId"`
	ID            string            `json:"id"`
	ParentID      string            `json:"parentId,omitempty"`
	Name          string            `json:"name"`
	Kind          string            `json:"kind,omitempty"`
	Timestamp     int64             `json:"timestamp"`
	Duration      int64             `json:"duration"`
	LocalEndpoint ZipkinEndpoint    `json:"localEndpoint"`
	Tags          map[string]string `json:"tags,omitempty"`
}

var (
	historyMutex   sync.RWMutex
	recentInvoices = make([]FacturaGenerada, 0)
	totalProcessed int
	zipkinClient   = &http.Client{Timeout: 2 * time.Second}
)

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}

func enableCORS(w http.ResponseWriter) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Ce-Specversion, Ce-Type, Ce-Source, Ce-Id, Ce-Time, Traceparent, X-B3-TraceId, X-B3-SpanId, X-B3-Sampled")
}

func getOrGenerateHex(bytesLen int) string {
	b := make([]byte, bytesLen)
	if _, err := rand.Read(b); err != nil {
		return fmt.Sprintf("%016x", time.Now().UnixNano())
	}
	return hex.EncodeToString(b)
}

func extractTraceContext(r *http.Request) TraceContext {
	tp := r.Header.Get("traceparent")
	if tp == "" {
		tp = r.Header.Get("Traceparent")
	}
	if tp == "" {
		tp = r.Header.Get("Ce-Traceparent")
	}

	var traceID, parentID string
	if tp != "" {
		parts := strings.Split(tp, "-")
		if len(parts) >= 3 && len(parts[1]) == 32 {
			traceID = parts[1]
			parentID = parts[2]
		}
	}

	if traceID == "" {
		b3Trace := r.Header.Get("x-b3-traceid")
		if b3Trace != "" {
			traceID = b3Trace
			parentID = r.Header.Get("x-b3-spanid")
		}
	}

	if traceID == "" {
		traceID = getOrGenerateHex(16)
	}

	spanID := getOrGenerateHex(8)

	return TraceContext{
		TraceID:  traceID,
		SpanID:   spanID,
		ParentID: parentID,
	}
}

func emitSpan(serviceName, spanName string, tc TraceContext, start time.Time, tags map[string]string) {
	zipkinURL := getEnv("OTEL_ZIPKIN_URL", "http://otel-collector.istio-system.svc.cluster.local:9411/api/v2/spans")
	if zipkinURL == "none" || zipkinURL == "" {
		return
	}

	durationMicros := time.Since(start).Microseconds()
	timestampMicros := start.UnixNano() / 1000

	span := ZipkinSpan{
		TraceID:   tc.TraceID,
		ID:        tc.SpanID,
		ParentID:  tc.ParentID,
		Name:      spanName,
		Kind:      "SERVER",
		Timestamp: timestampMicros,
		Duration:  durationMicros,
		LocalEndpoint: ZipkinEndpoint{
			ServiceName: serviceName,
		},
		Tags: tags,
	}

	payload, err := json.Marshal([]ZipkinSpan{span})
	if err != nil {
		return
	}

	go func(body []byte) {
		req, err := http.NewRequest("POST", zipkinURL, bytes.NewBuffer(body))
		if err != nil {
			return
		}
		req.Header.Set("Content-Type", "application/json")
		resp, err := zipkinClient.Do(req)
		if err == nil {
			_ = resp.Body.Close()
		}
	}(payload)
}

// eventsHandler procesa CloudEvents recibidos desde Knative Event Mesh (trigger-billing-ami)
func eventsHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	start := time.Now()
	tc := extractTraceContext(r)

	ceType := r.Header.Get("Ce-Type")
	ceID := r.Header.Get("Ce-Id")
	ceSource := r.Header.Get("Ce-Source")
	log.Printf("[BILLING EVENT] CloudEvent recibido: ID=%s Type=%s Source=%s Trace=%s", ceID, ceType, ceSource, tc.TraceID)

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
		nowStr := time.Now().UTC().Format(time.RFC3339)

		factura := FacturaGenerada{
			InvoiceID:      invoiceID,
			NIU:            lectura.NIU,
			Periodo:        periodo,
			TotalCOP:       totalCOP,
			KwhNetos:       netKwh,
			CreditoExc1Kwh: lectura.KwhExportados,
			Status:         "ISSUED",
			CreatedAt:      nowStr,
		}

		historyMutex.Lock()
		totalProcessed++
		recentInvoices = append([]FacturaGenerada{factura}, recentInvoices...)
		if len(recentInvoices) > 50 {
			recentInvoices = recentInvoices[:50]
		}
		historyMutex.Unlock()

		log.Printf("[BILLING] Factura generada con exito: %s para NIU %s | Total: $%.2f COP (Neto: %.2f kWh)",
			invoiceID, lectura.NIU, totalCOP, netKwh)

		// Emitir Span hacia OpenTelemetry / Application Insights con tags de negocio
		tags := map[string]string{
			"ce.id":                    ceID,
			"ce.type":                  ceType,
			"ce.source":                ceSource,
			"http.method":              "POST",
			"http.status_code":         "200",
			"voltera.event":            "ami.lectura_registrada",
			"voltera.niu":              lectura.NIU,
			"voltera.invoice_id":       invoiceID,
			"voltera.total_cop":        fmt.Sprintf("%.2f", totalCOP),
			"voltera.kwh_netos":        fmt.Sprintf("%.2f", netKwh),
			"voltera.credito_exc1_kwh": fmt.Sprintf("%.2f", lectura.KwhExportados),
		}
		emitSpan("billing-service", "billing.process_ami", tc, start, tags)

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
		w.Header().Set("Ce-Time", nowStr)
		// Propagación W3C Trace Context y B3 hacia el Broker
		w.Header().Set("traceparent", fmt.Sprintf("00-%s-%s-01", tc.TraceID, tc.SpanID))
		w.Header().Set("x-b3-traceid", tc.TraceID)
		w.Header().Set("x-b3-spanid", tc.SpanID)
		w.Header().Set("x-b3-sampled", "1")
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write(respBody)
		return
	}

	w.WriteHeader(http.StatusOK)
}

// generateInvoiceHandler atiende peticiones REST sincronas directas
func generateInvoiceHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	start := time.Now()
	tc := extractTraceContext(r)

	var req InvoiceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	log.Printf("Generando factura sincrona para cuenta %s por valor %.2f (Trace: %s)", req.AccountID, req.Total, tc.TraceID)

	paymentURL := getEnv("PAYMENT_URL", "http://payment-service:8081/process")
	paymentReq := PaymentRequest{
		AccountID: req.AccountID,
		Amount:    req.Total,
	}
	payload, _ := json.Marshal(paymentReq)

	httpReq, err := http.NewRequest("POST", paymentURL, bytes.NewBuffer(payload))
	paymentStatus := "FAILED"
	if err != nil {
		log.Printf("Error creando request a payment-service: %v", err)
	} else {
		httpReq.Header.Set("Content-Type", "application/json")
		httpReq.Header.Set("traceparent", fmt.Sprintf("00-%s-%s-01", tc.TraceID, tc.SpanID))
		httpReq.Header.Set("x-b3-traceid", tc.TraceID)
		httpReq.Header.Set("x-b3-spanid", tc.SpanID)
		httpReq.Header.Set("x-b3-sampled", "1")

		resp, postErr := http.DefaultClient.Do(httpReq)
		if postErr != nil {
			log.Printf("Error conectando a payment-service (%s): %v", paymentURL, postErr)
		} else {
			defer resp.Body.Close()
			body, _ := io.ReadAll(resp.Body)
			log.Printf("Respuesta de payment-service: %s", string(body))
			if resp.StatusCode == http.StatusOK {
				paymentStatus = "SUCCESS"
			}
		}
	}

	invoiceID := fmt.Sprintf("INV-%d", time.Now().UnixNano()/1000000)
	res := InvoiceResponse{
		InvoiceID:     invoiceID,
		Status:        "ISSUED",
		PaymentStatus: paymentStatus,
	}

	tags := map[string]string{
		"http.method":            "POST",
		"http.status_code":       "200",
		"voltera.account_id":     req.AccountID,
		"voltera.invoice_id":     invoiceID,
		"voltera.total_cop":      fmt.Sprintf("%.2f", req.Total),
		"voltera.payment_status": paymentStatus,
	}
	emitSpan("billing-service", "billing.generate_invoice_sync", tc, start, tags)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(res)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(w)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":    "healthy",
		"service":   "billing-service",
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	})
}

func statsHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(w)
	historyMutex.RLock()
	defer historyMutex.RUnlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"service":         "billing-service",
		"total_processed": totalProcessed,
		"recent_invoices": recentInvoices,
	})
}

func main() {
	port := getEnv("PORT", "8080")

	http.HandleFunc("/invoice", generateInvoiceHandler)
	http.HandleFunc("/events", eventsHandler)
	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/stats", statsHandler)

	log.Printf("Billing Service (Facturacion) iniciando en el puerto :%s...", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Error iniciando servidor: %v", err)
	}
}
