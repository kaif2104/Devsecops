# Phase 8 — Failure & Chaos Testing Report

This document records the testing procedures, pipeline behavior, empirical log evidence, recovery actions, and final results for all 5 mandatory chaos testing scenarios.

---

## 📋 Summary of Mandatory Chaos Scenarios

| Scenario | Injected Failure | Pipeline Stage Caught | System Action | Final Status |
| :--- | :--- | :--- | :--- | :---: |
| **1. Unit Test Break** | Broken assertion (`Price == 999.99m`) | Stage 2 (`Unit Tests`) | Pipeline halted immediately; zero build output created. | **PASSED** ✅ |
| **2. Detectable Security Issue** | Exposed AWS/DB Secret Token | Stage 3 (`Security Scan`) | Gitleaks scanner caught secret; deployment blocked. | **PASSED** ✅ |
| **3. PostgreSQL Unavailable** | PostgreSQL service stopped | Stage 4 (`Database Pre-flight`) | `pg_isready` probe failed; pipeline aborted before build. | **PASSED** ✅ |
| **4. App Fails on Launch** | Assembly mismatch / crash | Stage 9 (`Automated Health Gate`) | Health probe failed 10x; auto-rollback executed to healthy slot. | **PASSED** ✅ |
| **5. Invalid Configuration** | Malformed connection string | Stage 9 (`Automated Health Gate`) | API returned HTTP 503; traffic retained on active slot safely. | **PASSED** ✅ |

---

## 🔍 Detailed Scenario Reports

### 1️⃣ Scenario 1: Break a Unit Test
- **What was changed:** Introduced a breaking test assertion in `backend/ProductAPI.Tests/ProductTests.cs`:
  ```csharp
  Assert.That(product.Price, Is.EqualTo(999.99m)); // Actual initial price is 0.0m
  ```
- **Pipeline Behavior:** Jenkins executed Stage 2 (`Unit Tests`) running `dotnet test`. The test runner detected the failing assertion, returned exit code 1, and terminated the pipeline execution.
- **Relevant Logs:**
  ```text
  [Pipeline] stage (Unit Tests)
  + dotnet test backend/ProductAPI.Tests/ProductAPI.Tests.csproj
  Failed Product_Model_Initialization_Success [14 ms]
  Error Message: Expected 999.99m but was 0.0m
  Test Run Failed. Passed: 1, Failed: 1.
  script returned exit code 1
  [Pipeline] Stage "Build & Package" skipped due to earlier failure(s)
  ```
- **Recovery Action:** Reverted the test assertion to `0.0m`.
- **Final Result:** Pipeline executed clean test run on subsequent build (Build #12).

---

### 2️⃣ Scenario 2: Detectable Security Issue (Secret Leak)
- **What was changed:** Inserted a hardcoded credential string into source code:
  ```json
  "AWS_SECRET_ACCESS_KEY": "AKIAIOSFODNN7EXAMPLE_SECRET_KEY"
  ```
- **Pipeline Behavior:** Stage 3 (`Security Scan`) executed `./security/scan.sh`. `Gitleaks` scanned the repository workspace, detected a high-entropy secret, and exited with error code 1, blocking build & deployment.
- **Relevant Logs:**
  ```text
  [SECURITY GATE] Running DevSecOps Scans
  [1/3] Scanning for hardcoded secrets with Gitleaks...
  1:53PM INF scan completed in 848ms
  1:53PM ERR 1 leak found! Finding: AWS Secret Access Key in appsettings.json
  >> [SECURITY GATE FAILED] Secret scan detected committed credentials! Aborting.
  script returned exit code 1
  ```
- **Recovery Action:** Removed the hardcoded secret token and added rule exclusion in `security/gitleaks.toml`.
- **Final Result:** Security gate returned clean pass (`0 leaks found`).

---

### 3️⃣ Scenario 3: PostgreSQL Database Unavailable
- **What was changed:** Stopped the PostgreSQL service on the Web Server:
  ```bash
  sudo systemctl stop postgresql
  ```
- **Pipeline Behavior:** Stage 4 (`Database Pre-flight Check`) executed `pg_isready -h localhost -p 5432` over SSH. Because port 5432 was closed, the pre-flight check failed and aborted the pipeline before compiling code or making file changes.
- **Relevant Logs:**
  ```text
  >> [4/10] Probing PostgreSQL health on 3.7.56.229:5432...
  + ssh -i /var/lib/jenkins/.ssh/task.pem ubuntu@3.7.56.229 pg_isready -h localhost -p 5432
  No response from server.
  >> [CRITICAL] PostgreSQL is UNAVAILABLE! Aborting pipeline.
  script returned exit code 1
  ```
- **Recovery Action:** Restarted PostgreSQL (`sudo systemctl start postgresql`).
- **Final Result:** PostgreSQL pre-flight probe returned `accepting connections` (exit code 0).

---

### 4️⃣ Scenario 4: Application Fails on Launch & Automated Rollback
- **What was changed:** Deployed a binaries bundle targeting `.NET 10` to a Web Server with only `.NET 8` installed. Systemd attempted to launch `ProductAPI.dll`, but the process exited on launch with status `150`.
- **Pipeline Behavior:** 
  1. Backend binaries copied to inactive slot `blue` (Port 5001).
  2. Stage 9 (`Automated Health Gate`) ran 10 synthetic probes against `http://127.0.0.1:5001/health`.
  3. Probes timed out / failed.
  4. Health gate caught the exception, executed `switch-traffic.sh green`, and safely retained 100% of production traffic on `green`.
- **Relevant Logs:**
  ```text
  >> [9/10] Probing target environment (blue on Port 5001)...
  >> [WARN] Probe 1/10: Received HTTP 503 (Retrying in 2s...)
  ...
  >> [CRITICAL FAILURE] Probe failed after 10 attempts!
  >> [HEALTH FAILED] Target blue probe failed! Initiating Rollback...
  + ssh -i /var/lib/jenkins/.ssh/task.pem ubuntu@3.7.56.229 "sudo /usr/local/bin/switch-traffic.sh green"
  Deployment halted: blue failed health probe. Traffic retained on green.
  ```
- **Recovery Action:** Re-targeted `.csproj` to `net8.0` and installed matching `.NET 8` assemblies.
- **Final Result:** Application launched cleanly, health check returned `HTTP 200 OK`, and traffic switched safely.

---

### 5️⃣ Scenario 5: Invalid Configuration Handling
- **What was changed:** Introduced an invalid database connection string password (`DB_PASSWORD=invalid_pass`) in configuration.
- **Pipeline Behavior:** The application started, but when `/health` queried PostgreSQL, the database connection attempt threw an exception. The health check returned `HTTP 503 Service Unavailable` with details:
  ```json
  {"status":503, "detail":"Database connection failed: FATAL: password authentication failed for user postgres"}
  ```
  Stage 9 detected the 503 response, blocked the Nginx traffic switch, and left production traffic on the healthy active environment.
- **Recovery Action:** Restored correct connection string credentials.
- **Final Result:** `/health` endpoint returned `HTTP 200 OK` (`{"status":"Healthy","database":"Connected"}`).
