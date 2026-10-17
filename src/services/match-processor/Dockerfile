# Dockerfile para match-processor con idempotencia
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Copiar dependencias
COPY go.mod go.sum* ./
RUN go mod download

# Copiar código fuente
COPY *.go ./

# Compilar binario estático
RUN CGO_ENABLED=0 GOOS=linux go build -o match-processor .

# Imagen final minimal
FROM alpine:3.19

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copiar binario desde builder
COPY --from=builder /app/match-processor .

# Exponer puerto
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Ejecutar servicio
CMD ["./match-processor"]
