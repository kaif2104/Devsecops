# Deployment Guide & Procedures

## 1. Prerequisites & Environment Variables
- **Target OS:** Ubuntu 22.04 LTS
- **Runtime Dependencies:** .NET 8 SDK / ASP.NET Core Runtime, PostgreSQL 14+, Nginx
- **Required Secrets / Environment Variables:**
  - `DB_HOST`: Database host IP (`127.0.0.1` / `localhost`)
  - `DB_PORT`: PostgreSQL port (`5432`)
  - `DB_NAME`: Production database name (`productdb`)
  - `DB_USER` / `DB_PASSWORD`: PostgreSQL credentials

## 2. Automated Jenkins Deployment Pipeline
To deploy a new version to production:
1. Push code changes to the primary repository branch (`main`).
2. Jenkins automatically triggers `secops-production-pipeline`.
3. The pipeline runs all 10 stages automatically, including Unit Tests, SAST/Gitleaks scans, Database pre-checks, SQL backup, and active slot health probes.
4. Upon passing all quality gates, Nginx dynamically routes traffic to the newly deployed slot.

## 3. Manual Deployment Instructions (Emergency / Out-of-band)
In the event Jenkins is unreachable, run the following commands on the Web Server:
```bash
# 1. SSH into the Web Server
ssh ubuntu@3.7.56.229

# 2. Extract active environment
ACTIVE_ENV=$(cat /var/www/active_env.txt 2>/dev/null || echo "blue")
TARGET_ENV=$([ "$ACTIVE_ENV" = "blue" ] && echo "green" || echo "blue")

# 3. Copy application binaries to idle slot
sudo cp -r /tmp/build/* /var/www/${TARGET_ENV}/

# 4. Restart targeted systemd service
sudo systemctl restart productapi-${TARGET_ENV}

# 5. Verify local slot health probe
curl -f http://127.0.0.1:$([ "$TARGET_ENV" = "green" ] && echo "5002" || echo "5001")/health

# 6. Switch production traffic
sudo /usr/local/bin/switch-traffic.sh ${TARGET_ENV}
```
