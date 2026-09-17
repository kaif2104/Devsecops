#!/usr/bin/env bash
set -e
TARGET_URL=${1:-"http://127.0.0.1/health"}
MAX_RETRIES=10
RETRY_DELAY=2
echo "=================================================="
echo " [HEALTH GATE] Synthetic Probe on: $TARGET_URL"
echo "=================================================="
for ((i=1; i<=MAX_RETRIES; i++)); do
    HTTP_STATUS=$(curl -s -o /tmp/health_response.json -w "%{http_code}" "$TARGET_URL" || true)
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo ">> [PASS] Probe $i/$MAX_RETRIES: HTTP 200 OK"
        echo ">> Payload: $(cat /tmp/health_response.json)"
        echo ">> [HEALTH GATE] Service & Database are 100% HEALTHY!"
        exit 0
    else
        echo ">> [WARN] Probe $i/$MAX_RETRIES: Received HTTP $HTTP_STATUS (Retrying in ${RETRY_DELAY}s...)"
        sleep $RETRY_DELAY
    fi
done
echo ">> [CRITICAL FAILURE] Probe failed after $MAX_RETRIES attempts!"
echo ">> [HEALTH GATE] Health verification FAILED!"
exit 1
