#!/bin/sh
set -e

# Default database location on the Fly volume
DATABASE_URL="${DATABASE_URL:-file:/data/prod.db}"
export DATABASE_URL

echo "Running database migrations..."
npx prisma migrate deploy

echo "Starting server..."
exec node server.js
