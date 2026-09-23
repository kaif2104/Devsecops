#!/usr/bin/env bash
set -e

TARGET_HOST=${1:-"http://localhost"}

echo "=========================================================================="
echo " 🧪 [CONTROLLED SECURITY TESTING] DevSecOps Attack Simulation"
echo " Target Host: $TARGET_HOST"
echo "=========================================================================="

echo "[1/4] Simulating SQL Injection (SQLi) Request..."
curl -s -o /dev/null -w "HTTP Response Code: %{http_code}\n" \
  "$TARGET_HOST/api/products?search='%20UNION%20SELECT%201,2,3--" || true

echo "[2/4] Simulating Cross-Site Scripting (XSS) Request..."
curl -s -o /dev/null -w "HTTP Response Code: %{http_code}\n" \
  "$TARGET_HOST/api/products?query=%3Cscript%3Ealert(%27XSS%27)%3C/script%3E" || true

echo "[3/4] Simulating Brute-Force Authentication Attempt..."
for i in {1..5}; do
  curl -s -o /dev/null -X POST "$TARGET_HOST/api/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"invalid_password_attempt"}' || true
done
echo "Dispatched 5 invalid login attempts."

echo "[4/4] Security Gate Testing Command Instructions:"
echo "  - To test Gitleaks secret block, commit a dummy key string (e.g. AWS_KEY=MY_TEST_KEY) in a test branch."
echo "  - To test SAST block, introduce an un-sanitized raw SQL query string in Controllers."
echo "=========================================================================="
echo " ✅ Controlled simulation completed. Check AWS CloudWatch Logs & SNS Alerts."
echo "=========================================================================="
