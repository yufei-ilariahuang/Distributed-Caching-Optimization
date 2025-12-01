# Multi-stage build for GeeCache
# Stage 1: Build the Go application
FROM golang:alpine AS builder

# Install build dependencies
RUN apk add --no-cache git

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application for AMD64 (required for AWS Fargate)
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -v -o /app/server .

# Stage 2: Create minimal runtime image
FROM alpine:latest

# Install ca-certificates for HTTPS
RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder
COPY --from=builder /app/server ./geecache

# Expose ports
# 8001-8003 for cache nodes, 9999 for API
EXPOSE 8001 8002 8003 9999

# Default command (can be overridden in docker-compose)
ENTRYPOINT ["./geecache"]
CMD ["-port=8001"]
