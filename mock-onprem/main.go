package main

import (
	"bytes"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
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

type EmitResult struct {
	Status          string      `json:"status"`
	Message         string      `json:"message"`
	EventID         string      `json:"event_id"`
	SinkURL         string      `json:"sink_url"`
	LatencyMs       float64     `json:"latency_ms"`
	HTTPStatus      int         `json:"http_status"`
	Data            *AMILectura `json:"data"`
	EstimatedNetKwh float64     `json:"estimated_net_kwh"`
	EstimatedCOP    float64     `json:"estimated_cop"`
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}

func enableCORS(w http.ResponseWriter) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Ce-Specversion, Ce-Type, Ce-Source, Ce-Id, Ce-Time")
}

func emitReading(sinkURL string, custom *AMILectura) (*EmitResult, error) {
	lectura := AMILectura{
		NIU:              "1002345",
		MedidorSerie:     "MTR-COL-" + strconv.Itoa(1000+rand.Intn(9000)),
		TimestampLectura: time.Now().UTC().Format(time.RFC3339),
		Intervalo:        "MINUTOS_15",
		KwhImportados:    float64(rand.Intn(2000)) / 100.0,
		KwhExportados:    float64(rand.Intn(600)) / 100.0,
		TensionVoltios:   118.0 + (float64(rand.Intn(400)) / 100.0),
	}

	if custom != nil {
		if custom.NIU != "" {
			lectura.NIU = custom.NIU
		}
		if custom.MedidorSerie != "" {
			lectura.MedidorSerie = custom.MedidorSerie
		}
		if custom.KwhImportados > 0 || custom.KwhExportados > 0 {
			lectura.KwhImportados = custom.KwhImportados
			lectura.KwhExportados = custom.KwhExportados
		}
		if custom.TensionVoltios > 0 {
			lectura.TensionVoltios = custom.TensionVoltios
		}
	}

	payload, err := json.Marshal(lectura)
	if err != nil {
		return nil, fmt.Errorf("error serializando payload: %w", err)
	}

	req, err := http.NewRequest("POST", sinkURL, bytes.NewBuffer(payload))
	if err != nil {
		return nil, fmt.Errorf("error creando request: %w", err)
	}

	eventID := fmt.Sprintf("evt-ami-%d", time.Now().UnixNano())
	req.Header.Set("Ce-Specversion", "1.0")
	req.Header.Set("Ce-Type", "com.voltera.ami.lectura_registrada")
	req.Header.Set("Ce-Source", "//onprem/medidores/ami-mock")
	req.Header.Set("Ce-Id", eventID)
	req.Header.Set("Ce-Time", time.Now().UTC().Format(time.RFC3339))
	req.Header.Set("Content-Type", "application/json")

	tr := &http.Transport{
		TLSClientConfig: &tls.Config{
			InsecureSkipVerify: getEnv("TLS_INSECURE_SKIP_VERIFY", "true") == "true",
		},
	}
	client := &http.Client{
		Timeout:   10 * time.Second,
		Transport: tr,
	}

	start := time.Now()
	resp, err := client.Do(req)
	duration := time.Since(start)
	latencyMs := float64(duration.Microseconds()) / 1000.0

	if err != nil {
		return nil, fmt.Errorf("error enviando CloudEvent a %s: %w", sinkURL, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("el receptor (%s) respondió con HTTP %d", sinkURL, resp.StatusCode)
	}

	log.Printf("[ON-PREM SINK] CloudEvent enviado id=%s HTTP=%d Latencia=%.2fms", eventID, resp.StatusCode, latencyMs)

	netKwh := lectura.KwhImportados - lectura.KwhExportados
	estCOP := 5000.0
	if netKwh > 0 {
		estCOP = netKwh * 850.0
	}

	return &EmitResult{
		Status:          "success",
		Message:         "CloudEvent emitido exitosamente",
		EventID:         eventID,
		SinkURL:         sinkURL,
		LatencyMs:       latencyMs,
		HTTPStatus:      resp.StatusCode,
		Data:            &lectura,
		EstimatedNetKwh: netKwh,
		EstimatedCOP:    estCOP,
	}, nil
}

func main() {
	port := getEnv("PORT", "8080")
	sinkURL := getEnv("K_SINK", "http://broker-ingress.knative-eventing.svc.cluster.local/voltera-onprem/onprem-broker")
	cloudBillingURL := getEnv("CLOUD_BILLING_URL", "https://voltera-dev-mesh.eastus2.cloudapp.azure.com/api/billing/stats")
	cloudPaymentURL := getEnv("CLOUD_PAYMENT_URL", "https://voltera-dev-mesh.eastus2.cloudapp.azure.com/api/payment/stats")
	autoInterval := getEnv("AUTO_EMIT_INTERVAL", "")

	// 1. Servir Consola Web Interactiva en / y /ui
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" && r.URL.Path != "/ui" {
			http.NotFound(w, r)
			return
		}
		if data, err := os.ReadFile("index.html"); err == nil {
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			w.Write(data)
			return
		}
		if data, err := os.ReadFile("/app/index.html"); err == nil {
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			w.Write(data)
			return
		}
		w.Header().Set("Content-Type", "text/plain")
		w.Write([]byte("Voltera Mock AMI Online. Abre index.html para la interfaz interactiva."))
	})

	// 2. Health Probe
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		enableCORS(w)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":   "healthy",
			"region":   "onprem-local-k3s",
			"sink_url": sinkURL,
		})
	})

	// 3. Emisión de Eventos (GET o POST)
	http.HandleFunc("/emit", func(w http.ResponseWriter, r *http.Request) {
		enableCORS(w)
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}

		var custom AMILectura
		if r.Method == http.MethodPost && r.Body != nil {
			body, _ := io.ReadAll(r.Body)
			if len(body) > 0 {
				_ = json.Unmarshal(body, &custom)
			}
		}

		res, err := emitReading(sinkURL, &custom)
		w.Header().Set("Content-Type", "application/json")
		if err != nil {
			log.Printf("[ERROR] Emisión fallida: %v", err)
			w.WriteHeader(http.StatusBadGateway)
			json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
			return
		}
		json.NewEncoder(w).Encode(res)
	})

	// 4. Proxy de Estado del Cloud (para alimentar la UI)
	http.HandleFunc("/cloud-status", func(w http.ResponseWriter, r *http.Request) {
		enableCORS(w)
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}

		tr := &http.Transport{TLSClientConfig: &tls.Config{InsecureSkipVerify: true}}
		client := &http.Client{Timeout: 3 * time.Second, Transport: tr}

		var billingData interface{}
		var paymentData interface{}

		if resp, err := client.Get(cloudBillingURL); err == nil && resp.StatusCode == 200 {
			defer resp.Body.Close()
			_ = json.NewDecoder(resp.Body).Decode(&billingData)
		}
		if resp, err := client.Get(cloudPaymentURL); err == nil && resp.StatusCode == 200 {
			defer resp.Body.Close()
			_ = json.NewDecoder(resp.Body).Decode(&paymentData)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"billing": billingData,
			"payment": paymentData,
		})
	})

	// 5. Consumidor de Eventos (Sink)
	http.HandleFunc("/events", func(w http.ResponseWriter, r *http.Request) {
		enableCORS(w)
		log.Printf("[ON-PREM RECEIVER] Evento recibido: Type=%s, ID=%s",
			r.Header.Get("Ce-Type"), r.Header.Get("Ce-Id"))
		w.WriteHeader(http.StatusOK)
	})

	if autoInterval != "" {
		if d, err := time.ParseDuration(autoInterval); err == nil && d > 0 {
			go func() {
				ticker := time.NewTicker(d)
				for range ticker.C {
					if _, err := emitReading(sinkURL, nil); err != nil {
						log.Printf("[AUTO-EMIT WARN] %v", err)
					}
				}
			}()
			log.Printf("[INFO] Emisión automática activada cada %s", autoInterval)
		}
	}

	log.Printf("Iniciando Mock AMI On-Prem en puerto :%s (K_SINK=%s)", port, sinkURL)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Error en servidor: %v", err)
	}
}
