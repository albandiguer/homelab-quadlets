#!/bin/bash
set -e

# This script ensures the 'plane' bucket exists and is publicly readable.
# CORS is handled by MINIO_API_CORS_* environment variables in the container.

echo "Waiting for MinIO to be ready..."
until curl -fsS http://plane:9000/minio/health/live >/dev/null 2>&1; do
    sleep 2
done

# Install mc if not present (minio server image may not include it)
if ! command -v mc >/dev/null 2>&1; then
    echo "Installing mc (MinIO client)..."
    curl -sSL https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/local/bin/mc
    chmod +x /usr/local/bin/mc
fi

# Set up mc alias
mc alias set local http://plane:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" --insecure 2>/dev/null || true

# Create bucket if it doesn't exist
if ! mc ls local/plane >/dev/null 2>&1; then
    echo "Creating 'plane' bucket..."
    mc mb local/plane
fi

# Set bucket policy to allow public read (needed for serving uploaded images/attachments)
echo "Setting bucket to public read..."
mc anonymous set download local/plane 2>/dev/null || true

echo "MinIO bucket configured"
