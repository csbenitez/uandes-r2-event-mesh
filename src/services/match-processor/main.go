package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/go-redis/redis/v8"
	_ "github.com/lib/pq"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// MatchEvent representa el evento de emparejamiento P2P
type MatchEvent struct {
	MatchID    string  `json:"match_id"`
	ProsumerID string  `json:"prosumer_id"`
	ConsumerID string  `json:"consumer_id"`
	KwhMatched float64 `json:"kwh_matched"`
	PriceCOP   float64 `json:"price_cop"`
	Timestamp  string  `json:"timestamp"`
}

// Métricas Prometheus
var (
	matchesReceived = promauto.NewCounter(prometheus.CounterOpts{
		Name: "matches_received_total",
		Help: "Total de eventos de match recibidos",
	})

	matchesUniqueProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "matches_unique_processed",
		Help: "Eventos únicos procesados exitosamente",
	})

	matchesDuplicatesDetected = promauto.NewCounter(prometheus.CounterOpts{
		Name: "matches_duplicates_detected",
		Help: "Eventos duplicados detectados y rechazados",
	})

	idempotencyCacheHits = promauto.NewCounter(prometheus.CounterOpts{
		Name: "idempotency_cache_hits",
		Help: "Verificaciones de idempotencia resueltas desde Redis",
	})

	idempotencyCheckDuration = promauto.NewHistogram(prometheus.HistogramOpts{
		Name:    "idempotency_check_duration_seconds",
		Help:    "Duración de la verificación de idempotencia",
		Buckets: prometheus.DefBuckets,
	})
)

// MatchProcessor maneja el procesamiento idempotente de matches
type MatchProcessor struct {
	db    *sql.DB
	redis *redis.Client
	ctx   context.Context
}

func NewMatchProcessor(db *sql.DB, redisClient *redis.Client) *MatchProcessor {
	return &MatchProcessor{
		db:    db,
		redis: redisClient,
		ctx:   context.Background(),
	}
}

// ProcessMatch implementa el procesamiento idempotente según material ARTI4208
func (mp *MatchProcessor) ProcessMatch(event MatchEvent) error {
	matchesReceived.Inc()

	// Regla 1: Clave estable del negocio
	// El matchID viene del productor, no se genera aquí
	matchID := event.MatchID

	// Regla 2: Transacción atómica (MARCAR PRIMERO + verificar + efecto)
	// CRÍTICO: La marca debe ser el PRIMER INSERT para evitar race conditions
	tx, err := mp.db.Begin()
	if err != nil {
		return fmt.Errorf("error starting transaction: %w", err)
	}
	defer tx.Rollback()

	// Fast path: Verificar Redis primero (cache) ANTES de la transacción costosa
	cacheKey := fmt.Sprintf("processed:%s", matchID)
	redisExists, err := mp.redis.Exists(mp.ctx, cacheKey).Result()
	if err == nil && redisExists > 0 {
		idempotencyCacheHits.Inc()
		matchesDuplicatesDetected.Inc()
		log.Printf("[CACHE HIT] Duplicate detected in Redis: %s", matchID)
		return nil // ACK sin procesar
	}

	// MARCA DE IDEMPOTENCIA PRIMERO (para bloquear la clave)
	// Usar INSERT ... ON CONFLICT DO NOTHING para idempotencia atómica
	result, err := tx.Exec(`
		INSERT INTO processed_events (idempotency_key, event_type, processed_at)
		VALUES ($1, 'com.voltera.match.created', NOW())
		ON CONFLICT (idempotency_key) DO NOTHING
	`, matchID)

	if err != nil {
		return fmt.Errorf("error marking as processed: %w", err)
	}

	// Verificar si el INSERT fue exitoso (RowsAffected = 1) o si ya existía (RowsAffected = 0)
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("error checking rows affected: %w", err)
	}

	if rowsAffected == 0 {
		// Ya existía - DUPLICADO detectado por constraint
		matchesDuplicatesDetected.Inc()
		log.Printf("[DUPLICATE-DB] MatchID=%s already processed (detected by constraint)", matchID)
		return nil // ACK sin reprocesar
	}

	// Si llegamos aquí, somos el ÚNICO que insertó la marca
	// Ahora podemos hacer el efecto de negocio con seguridad

	// EFECTO DE NEGOCIO: Insertar match
	_, err = tx.Exec(`
		INSERT INTO matches (match_id, prosumer_id, consumer_id, kwh_matched, price_cop, created_at)
		VALUES ($1, $2, $3, $4, $5, NOW())
	`, matchID, event.ProsumerID, event.ConsumerID, event.KwhMatched, event.PriceCOP)

	if err != nil {
		return fmt.Errorf("error inserting match: %w", err)
	}

	// Commit atómico: marca + efecto juntos
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("error committing transaction: %w", err)
	}

	// Actualizar cache Redis (TTL 24h) - DESPUÉS del commit
	mp.redis.Set(mp.ctx, cacheKey, "1", 24*time.Hour)

	matchesUniqueProcessed.Inc()
	log.Printf("[PROCESSED] MatchID=%s | Prosumer=%s → Consumer=%s | %.2f kWh @ $%.2f COP",
		matchID, event.ProsumerID, event.ConsumerID, event.KwhMatched, event.PriceCOP)

	return nil
}

// eventsHandler maneja CloudEvents desde Knative Event Mesh
func (mp *MatchProcessor) eventsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	ceType := r.Header.Get("Ce-Type")
	ceID := r.Header.Get("Ce-Id")
	ceSource := r.Header.Get("Ce-Source")

	log.Printf("[EVENT] Received CloudEvent: ID=%s Type=%s Source=%s", ceID, ceType, ceSource)

	if ceType != "com.voltera.match.created" && ceType != "" {
		log.Printf("[WARN] Ignoring unsupported event type: %s", ceType)
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]string{
			"status": "ignored",
			"reason": "unsupported event type",
		})
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Error reading body", http.StatusBadRequest)
		return
	}

	var event MatchEvent
	if err := json.Unmarshal(body, &event); err != nil {
		log.Printf("[ERROR] Invalid JSON payload: %v", err)
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	// Validar que matchID no esté vacío (clave del negocio)
	if event.MatchID == "" {
		log.Printf("[ERROR] Missing match_id in event")
		http.Error(w, "Missing match_id", http.StatusBadRequest)
		return
	}

	// Procesar con idempotencia
	if err := mp.ProcessMatch(event); err != nil {
		log.Printf("[ERROR] Failed to process match: %v", err)
		http.Error(w, "Processing error", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"status":   "processed",
		"match_id": event.MatchID,
	})
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "healthy",
		"service": "match-processor",
	})
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}

func main() {
	// Configuración desde variables de entorno
	port := getEnv("PORT", "8080")
	dbHost := getEnv("DB_HOST", "postgres-matches")
	dbPort := getEnv("DB_PORT", "5432")
	dbUser := getEnv("DB_USER", "voltera")
	dbPassword := getEnv("DB_PASSWORD", "voltera_pass")
	dbName := getEnv("DB_NAME", "voltera_matches")
	redisHost := getEnv("REDIS_HOST", "redis-idempotency")
	redisPort := getEnv("REDIS_PORT", "6379")

	// Conectar a PostgreSQL
	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		dbHost, dbPort, dbUser, dbPassword, dbName)

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatalf("Failed to connect to PostgreSQL: %v", err)
	}
	defer db.Close()

	// Verificar conexión
	if err := db.Ping(); err != nil {
		log.Fatalf("Failed to ping PostgreSQL: %v", err)
	}
	log.Printf("✅ Connected to PostgreSQL: %s", dbName)

	// Conectar a Redis
	redisAddr := fmt.Sprintf("%s:%s", redisHost, redisPort)
	redisClient := redis.NewClient(&redis.Options{
		Addr:     redisAddr,
		Password: "",
		DB:       0,
	})

	ctx := context.Background()
	if err := redisClient.Ping(ctx).Err(); err != nil {
		log.Printf("⚠️  Redis not available (will use DB only): %v", err)
	} else {
		log.Printf("✅ Connected to Redis: %s", redisAddr)
	}

	// Inicializar procesador
	processor := NewMatchProcessor(db, redisClient)

	// Endpoints
	http.HandleFunc("/events", processor.eventsHandler)
	http.HandleFunc("/health", healthHandler)
	http.Handle("/metrics", promhttp.Handler())

	log.Printf("🚀 Match Processor (Idempotent) starting on port :%s...", port)
	log.Printf("📡 Event endpoint: POST /events")
	log.Printf("💚 Health endpoint: GET /health")
	log.Printf("📊 Metrics endpoint: GET /metrics")

	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
