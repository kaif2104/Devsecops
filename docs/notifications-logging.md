# Phase 7 — Notifications & Logging Guide

This document outlines the notification mechanisms, logging architecture, and step-by-step diagnostic workflows used to investigate failed builds, HTTP 500 errors, or deployment rollbacks.

---

## 📢 1. Notification Architecture

The pipeline implements structured notification hooks in the `post` block of the `Jenkinsfile` that trigger automatically upon pipeline completion or failure.

### 📌 Notification Payload Fields
Every notification contains metadata required for SecOps auditing:
- **Application / Service:** `ProductAPI (.NET 8 + React Frontend)`
- **Version / Commit:** Git SHA (`git rev-parse --short HEAD`) & Branch (`main`)
- **Build Number:** Jenkins `${env.BUILD_NUMBER}`
- **Pipeline Stage / Result:** `SUCCESS`, `FAILURE`, or `UNSTABLE`
- **Target Deployment Slot:** `blue` or `green`
- **Rollback Status:** `TRUE` (Traffic retained on previous slot) or `FALSE` (Traffic switched)
- **Live Production URL:** `http://3.7.56.229`

### 💻 Jenkins Pipeline Notification Implementation (`Jenkinsfile`)
```groovy
post {
    always {
        script {
            def commitHash = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
            echo """
================================================================================
 📢 PIPELINE NOTIFICATION SUMMARY
================================================================================
 • Application: ProductAPI (.NET 8 + React Frontend)
 • Version / Commit: ${commitHash} (Branch: ${env.BRANCH_NAME})
 • Build Number: #${env.BUILD_NUMBER}
 • Pipeline Result: ${currentBuild.currentResult}
 • Target Deployment Slot: ${env.TARGET_ENV}
 • Active Production Slot: ${env.ACTIVE_ENV}
 • Rollback Executed: ${env.ROLLBACK_EXECUTED}
 • Production URL: http://${WEB_SERVER_IP}
================================================================================
"""
        }
    }
    success {
        script {
            echo "✅ [NOTIFICATION SUCCESS] Deployment completed successfully! Live URL: http://${WEB_SERVER_IP}"
        }
    }
    failure {
        script {
            echo "❌ [NOTIFICATION ALERT] Pipeline Quality Gate Blocked Deployment! Automated Protection / Rollback Triggered."
        }
    }
}
```

---

## 📜 2. Centralized Logging Architecture

The environment collects logs across four layers:

```
[1. Jenkins CI Logs] ➔ [2. Nginx Access/Error Logs] ➔ [3. Systemd Application Logs] ➔ [4. PostgreSQL Audit Logs]
```

| Layer | Log File / Source | Description & Commands |
| :--- | :--- | :--- |
| **1. Jenkins Build Logs** | `http://13.234.216.249:8080/job/secops-production-pipeline/BUILD_ID/console` | CI/CD pipeline step output, build compilation, test results, and scanner outputs. |
| **2. Nginx Web Server** | `/var/log/nginx/access.log`<br>`/var/log/nginx/error.log` | HTTP request status codes (200, 403, 500, 503), client IPs, and proxy routing. |
| **3. .NET 8 Backend** | `sudo journalctl -u productapi-blue.service -n 100`<br>`sudo journalctl -u productapi-green.service -n 100` | C# unhandled exceptions, Kestrel startup errors, assembly loading failures, and database connection strings. |
| **4. PostgreSQL Database** | `/var/log/postgresql/postgresql-14-main.log` | Database connection attempts, migration SQL queries, connection pool exhaustion, and deadlock errors. |

---

## 🔎 3. Step-by-Step Investigation Workflow (HTTP 500 / Deployment Failure)

### Scenario: Investigating an HTTP 500 or Post-Deployment Health Check Failure

When a deployment fails or an HTTP 500 error occurs, follow this exact 4-step diagnostic procedure:

#### Step 1: Check Jenkins Pipeline Console Output
Look at the pipeline stage where execution halted:
```bash
# Example Jenkins output:
>> [HEALTH FAILED] Target blue probe failed! Initiating Rollback...
```

#### Step 2: Inspect Nginx Reverse Proxy Error Logs
Connect to the Web Server (`3.7.56.229`) and view Nginx error logs:
```bash
ssh ubuntu@3.7.56.229
sudo tail -n 50 /var/log/nginx/error.log
```
*Look for upstream connection refused or HTTP status codes.*

#### Step 3: Inspect Systemd Service & Kestrel Application Journal Logs
View the real-time runtime log of the targeted backend slot (`productapi-blue` or `productapi-green`):
```bash
sudo journalctl -u productapi-blue.service -n 50 --no-pager
```
*Example Diagnostic Evidence Found During Failure Testing:*
```text
productapi-blue[2990]: Service Unavailable: Database connection failed: 
Could not load file or assembly 'System.Diagnostics.DiagnosticSource, Version=9.0.0.0'
```

#### Step 4: Inspect PostgreSQL Database Server Logs
Verify if the database refused connections or encountered a query error:
```bash
sudo tail -n 50 /var/log/postgresql/postgresql-14-main.log
```

---

## 🎯 Summary
By combining **automated post notifications** with **multi-tier log inspection (Jenkins → Nginx → Systemd → PostgreSQL)**, the team has total visibility into pipeline state, instant security failure alerts, and fast root-cause resolution.
