# DevSecOps Security Gate & Attack Detection Report

**Project**: ProductAPI CI/CD Pipeline & Cloud Security  
**Phase**: Phase 5 — CI/CD Security Monitoring & Attack Detection  
**Author**: Junior DevSecOps Engineer (Guided by Senior DevOps Engineer)  

---

## 1. Executive Summary

This report documents the implementation of automated **Shift-Left Security** and **Real-Time Attack Detection** for the ProductAPI application. Security controls were integrated into the GitHub Actions CI/CD pipeline, and CloudWatch Log Metric Filters and SNS Alarms were configured to detect production attack patterns.

---

## 2. CI/CD Security Gate Findings & Pipeline Protection

### A. Secret Scanning (Gitleaks)
* **What was detected**: Attempts to commit API keys, database connection strings, or cloud secret tokens.
* **Location**: File repository & Git history.
* **Pipeline Action**: Gitleaks exits with code `1`, causing the `security-gate` job in GitHub Actions to **FAIL**, preventing deployment to EC2.

### B. Static Application Security Testing (Semgrep SAST)
* **What was detected**: SQL injection vulnerabilities (raw string concatenation in database queries), XSS risks, and insecure system commands.
* **Location**: Application controllers and models (`backend/Controllers/`).
* **Pipeline Action**: Semgrep flags vulnerabilities with severity `--error`, halting the pipeline prior to deployment.

### C. Dependency Scanning (SCA)
* **What was detected**: Known CVEs in NuGet packages (`dotnet list package --vulnerable`) and npm modules (`npm audit`).
* **Threshold**: Any `High` or `Critical` severity vulnerability triggers a Security Gate failure.

---

## 3. AWS CloudWatch Real-Time Attack Detection & SNS Alerting

| Attack Type | Detection Filter Location | Trigger Condition | SNS Alert Topic |
| :--- | :--- | :--- | :--- |
| **SQL Injection (SQLi)** | Nginx access logs / App logs | URI/payload matching `UNION`, `SELECT`, `OR 1=1`, `--` | `DevSecOps-Security-Alerts` |
| **Cross-Site Scripting (XSS)** | Nginx access logs | URI/payload matching `<script>`, `javascript:`, `onerror=` | `DevSecOps-Security-Alerts` |
| **Brute-Force Login** | Application Auth logs | HTTP `401 Unauthorized` responses >= 10 in 5 min | `DevSecOps-Security-Alerts` |
| **SSH Auth Failure** | `/var/log/auth.log` | `Failed password` or `Invalid user` >= 3 in 1 min | `DevSecOps-Security-Alerts` |

---

## 4. How Security Controls Prevent Insecure Releases

1. **Shift-Left Enforcement**: By running scans in GitHub Actions *before* the deployment step (`needs: security-gate`), insecure code never reaches the EC2 production instance.
2. **Real-Time Operational Security**: If an attacker attempts to exploit an endpoint in production, CloudWatch Log Metric Filters capture the signature within 60 seconds, triggering an instant SNS notification to the DevSecOps team for incident response.
