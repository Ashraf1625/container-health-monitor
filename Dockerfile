# Production Dockerfile for Container Health Monitor
# This is used by Railway for deployment

FROM docker:26-dind

# Install Docker Compose
RUN apk add --no-cache \
    docker-compose \
    bash \
    curl \
    postgresql-client \
    python3 \
    py3-pip

# Copy project files
WORKDIR /app
COPY . /app/

# Set permissions
RUN chmod +x *.sh

# Expose ports
EXPOSE 3000 8000 5432 9090 3001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Start services
CMD ["docker-compose", "up"]
