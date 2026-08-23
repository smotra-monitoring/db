#!/bin/sh
set -e

echo "Starting database migration..."

# Ensure the DATABASE_URL is provided by the Kubernetes Secret
if [ -z "$DATABASE_URL" ]; then
  echo "Error: DATABASE_URL environment variable is not set."
  exit 1
fi

# Run go-migrate pointing to the bundled migrations folder
/usr/local/bin/migrate \
  -path /app/migrations \
  -database "$DATABASE_URL" \
  up

echo "Database migration completed successfully!"
