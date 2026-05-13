#!/bin/bash
set -e

echo "Container Health Monitor - Starting on Railway"
echo "Environment: Production"
echo "=============================================="

# Check if running on Railway
if [ -z "\$RAILWAY_ENVIRONMENT_NAME\" ]; then
    echo "Not on Railway. Exiting."
    exit 1
fi

# Start services
echo "Starting Docker Compose services..."
docker-compose up --build --remove-orphans

echo "Services started successfully!"