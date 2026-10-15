FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY go.mod ./
COPY main.go ./

RUN CGO_ENABLED=0 GOOS=linux go build -o payment-service .

FROM alpine:3.19
WORKDIR /root/
COPY --from=builder /app/payment-service .

EXPOSE 8081
CMD ["./payment-service"]
