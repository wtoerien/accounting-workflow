#!/bin/sh
set -e

mkdir -p /data

echo "Running database migrations..."
npx prisma migrate deploy

echo "Starting server..."
exec npm start
