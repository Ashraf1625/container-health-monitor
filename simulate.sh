#!/bin/bash
# Simulation script for Presentation
# It generates HTTP traffic for Grafana and Docker events/stats for the React Dashboard

echo "=============================================="
echo " Starting Container Health Monitor Simulation "
echo "=============================================="

# 1. Start dummy containers to show CPU and Memory usage in React Dashboard
echo "--> Spinning up dummy containers..."
docker run -d --name demo-cpu-load --rm alpine sh -c "while true; do yes > /dev/null; done"
docker run -d --name demo-mem-load --rm alpine sh -c "dd if=/dev/urandom of=/dev/shm/file1 bs=1M count=100 && sleep 3600"
docker run -d --name demo-web-server --rm nginx:alpine

echo "--> Dummy containers running."
echo "--> Generating HTTP traffic (for Grafana charts) and triggering operations (for Logs)..."
echo "    (Press CTRL+C to stop simulation and clean up)"

# Trap CTRL+C to cleanup
trap "echo -e '\n--> Cleaning up dummy containers...'; docker stop demo-cpu-load demo-mem-load demo-web-server 2>/dev/null; exit 0" SIGINT SIGTERM

API_URL="http://localhost:8000"

# Loop to generate traffic and events
count=0
while true; do
  # Generate regular HTTP traffic for Grafana
  curl -s $API_URL/health > /dev/null
  curl -s $API_URL/containers > /dev/null
  curl -s $API_URL/events > /dev/null

  # Every 20 iterations (approx 10 seconds), restart a container to generate an event
  if [ $((count % 20)) -eq 0 ] && [ $count -gt 0 ]; then
    echo "[Event] Restarting demo-web-server via API..."
    curl -s -X POST $API_URL/containers/demo-web-server/restart > /dev/null
  fi

  # Every 45 iterations, stop and recreate a container to generate a Stop event
  if [ $((count % 45)) -eq 0 ] && [ $count -gt 0 ]; then
    echo "[Event] Stopping demo-mem-load via API..."
    curl -s -X POST $API_URL/containers/demo-mem-load/stop > /dev/null
    sleep 2
    # recreate it quietly
    docker run -d --name demo-mem-load --rm alpine sh -c "dd if=/dev/urandom of=/dev/shm/file1 bs=1M count=100 && sleep 3600" > /dev/null
  fi

  count=$((count + 1))
  sleep 0.5
done
