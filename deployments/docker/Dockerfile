# --- Stage 1: Get the official go-migrate binary ---
FROM migrate/migrate:latest AS migrate-bin

# --- Stage 2: Runtime Image ---
FROM alpine:3.19

# Install runtime certificates for secure database connections (e.g., TLS)
RUN apk add --no-cache ca-certificates

# Copy the go-migrate binary from the official image
COPY --from=migrate-bin /usr/local/bin/migrate /usr/local/bin/migrate

# Set up the working directory
WORKDIR /app

# Copy the local migrations folder into the container
COPY ./prod/migrations /app/migrations

# Copy the execution script
COPY ./deployments/docker/run_migrations.sh /app/run-migrations.sh
RUN chmod +x /app/run-migrations.sh

# Run the script by default
ENTRYPOINT ["./run-migrations.sh"]
