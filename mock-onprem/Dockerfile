FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod ./
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -o mock-service .

FROM alpine:3.19
WORKDIR /root/
COPY --from=builder /app/mock-service .
EXPOSE 8080
CMD ["./mock-service"]
