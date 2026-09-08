#!/bin/sh
set -e

echo "Starting database migration..."

if [ -z "$DATABASE_HOST" ]; then
  echo "Error: DATABASE_HOST environment variable is not set."
  exit 1
fi
if [ -z "$DATABASE_PORT" ]; then
  echo "Error: DATABASE_PORT environment variable is not set."
  exit 1
fi

if [ -z "$DATABASE_USER" ]; then
  echo "Error: DATABASE_USER environment variable is not set."
  exit 1
fi

if [ -z "$DATABASE_PASSWORD" ]; then
  echo "Error: DATABASE_PASSWORD environment variable is not set."
  exit 1
fi

if [ -z "$DATABASE_NAME" ]; then
  echo "Error: DATABASE_NAME environment variable is not set."
  exit 1
fi

if [ -z "$DATABASE_SSLMODE" ]; then
  echo "Error: DATABASE_SSLMODE environment variable is not set."
  exit 1
fi

# Run go-migrate pointing to the bundled migrations folder
/usr/local/bin/migrate \
  -path /app/migrations \
  -database "postgresql://$DATABASE_USER:$DATABASE_PASSWORD@$DATABASE_HOST:$DATABASE_PORT/$DATABASE_NAME?sslmode=$DATABASE_SSLMODE" \
  up

echo "Database migration completed successfully!"
