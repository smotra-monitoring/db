# --- Stage 1: Get the official go-migrate binary ---
FROM migrate/migrate:v4 AS migrate-bin

# --- Stage 2: Runtime Image ---
FROM alpine:3.19

# Install runtime certificates for secure database connections (e.g., TLS)
RUN apk add --no-cache ca-certificates

# Copy the go-migrate binary from the official image
COPY --from=migrate-bin /usr/local/bin/migrate /usr/local/bin/migrate

# Set up the working directory
WORKDIR /app

# Copy the local migrations folder into the container
COPY ./migrations /app/migrations

# Copy the execution script
COPY ./run-migrations.sh /app/run-migrations.sh
RUN chmod +x /app/run-migrations.sh

# Run the script by default
ENTRYPOINT ["./run-migrations.sh"]
