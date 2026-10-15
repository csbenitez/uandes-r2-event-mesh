FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY go.mod ./
COPY main.go ./

RUN CGO_ENABLED=0 GOOS=linux go build -o billing-service .

FROM alpine:3.19
WORKDIR /root/
COPY --from=builder /app/billing-service .

EXPOSE 8080
CMD ["./billing-service"]
