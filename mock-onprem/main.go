package main

import (
	"bytes"
	"crypto/tls"
	"encoding/json"
	"fmt"
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

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}

func emitReading(sinkURL string) (*AMILectura, error) {
	lectura := AMILectura{
		NIU:              "1002345",
		MedidorSerie:     "MTR-COL-" + strconv.Itoa(1000+rand.Intn(9000)),
		TimestampLectura: time.Now().UTC().Format(time.RFC3339),
		Intervalo:        "MINUTOS_15",
		KwhImportados:    float64(rand.Intn(2000)) / 100.0,
		KwhExportados:    float64(rand.Intn(600)) / 100.0,
		TensionVoltios:   118.0 + (float64(rand.Intn(400)) / 100.0),
	}

	payload, err := json.Marshal(lectura)
	if err != nil {
		return nil, fmt.Errorf("error serializando payload: %w", err)
	}

	req, err := http.NewRequest("POST", sinkURL, bytes.NewBuffer(payload))
	if err != nil {
		return nil, fmt.Errorf("error creando request: %w", err)
	}

	// Encabezados CloudEvents v1.0 (Binary Mode)
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
		Timeout:   5 * time.Second,
		Transport: tr,
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("error enviando CloudEvent a %s: %w", sinkURL, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("el receptor (%s) respondió con código: %d", sinkURL, resp.StatusCode)
	}

	log.Printf("[ON-PREM SINK] CloudEvent enviado exitosamente id=%s type=com.voltera.ami.lectura_registrada HTTP=%d", eventID, resp.StatusCode)
	return &lectura, nil
}

func main() {
	port := getEnv("PORT", "8080")
	sinkURL := getEnv("K_SINK", "http://broker-ingress.knative-eventing.svc.cluster.local/voltera/default")
	autoInterval := getEnv("AUTO_EMIT_INTERVAL", "") // ej. "10s" para emisión periódica

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":  "healthy",
			"region":  "onprem-local-k3s",
			"sink_url": sinkURL,
		})
	})

	http.HandleFunc("/emit", func(w http.ResponseWriter, r *http.Request) {
		lectura, err := emitReading(sinkURL)
		w.Header().Set("Content-Type", "application/json")
		if err != nil {
			log.Printf("[ERROR] Emisión manual fallida: %v", err)
			w.WriteHeader(http.StatusBadGateway)
			json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
			return
		}
		json.NewEncoder(w).Encode(map[string]interface{}{
			"message": "CloudEvent emitido exitosamente",
			"data":    lectura,
		})
	})

	// Receptor de eventos (Sink/Consumer) para verificar recepción
	http.HandleFunc("/events", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("[ON-PREM RECEIVER] Evento recibido desde Cloud/Mesh: Type=%s, ID=%s",
			r.Header.Get("Ce-Type"), r.Header.Get("Ce-Id"))
		w.WriteHeader(http.StatusOK)
	})

	if autoInterval != "" {
		if d, err := time.ParseDuration(autoInterval); err == nil && d > 0 {
			go func() {
				ticker := time.NewTicker(d)
				for range ticker.C {
					if _, err := emitReading(sinkURL); err != nil {
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
