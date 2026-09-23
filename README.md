# Phase 5 — CI/CD Security Monitoring & Attack Detection

## 🛡️ Architecture & DevSecOps Flow

```
[Developer] -> Git Push
                  │
                  ▼
       [GitHub Actions Workflow]
                  │
                  ├───────────────► 1. Build & Unit Tests
                  │
                  ▼
      [SECURITY GATE (security/scan.sh)]
                  │
                  ├──► SCA (Dependency Vulnerability Scan - NuGet & npm)
                  ├──► Secret Detection (Gitleaks - API keys, tokens, passwords)
                  └──► SAST (Semgrep Static Application Security Testing)
                  │
         ┌────────┴────────┐
         ▼                 ▼
   [FAIL: Stop]     [PASS: Proceed]
                           │
                           ▼
                  Deploy to AWS EC2 (Blue/Green Slot)
                           │
                           ▼
               [Live Web App + Nginx Logs]
                           │
                           ▼
               [AWS CloudWatch Logs Stream]
                           │
             ┌─────────────┴─────────────┐
             ▼                           ▼
  [CloudWatch Metric Filters]  [CloudWatch Alarms]
  - SQL Injection Patterns     - Threshold >= 1 or 10
  - XSS Injection Patterns               │
  - Brute-Force Logins                   ▼
  - SSH Auth Failures             [Amazon SNS Alerting]
                                         │
                                         ▼
                             [Security Email/PagerAlert]
```

---

## 🚀 Security Gate Controls & Thresholds

1. **Dependency Scanning (SCA)**: Scans `.NET` NuGet and `npm` packages. Deployment is blocked if `High` or `Critical` severity CVE vulnerabilities are present.
2. **Secret Detection**: Gitleaks checks code against `security/gitleaks.toml`. Pipeline halts immediately if AWS credentials, DB passwords, or API secrets are detected.
3. **SAST (Static Analysis)**: Semgrep scans source code for security anti-patterns (e.g. SQL Injection risks, XSS flaws, hardcoded secrets).

---

## 📊 AWS CloudWatch Attack Detection Rules

The following log metric filters and alarms are configured in `monitoring/cloudwatch-metric-filters.json` and `monitoring/cloudwatch-alarms.json`:

| Detection Category | Metric Filter Pattern | Alarm Condition | SNS Notification |
| :--- | :--- | :--- | :--- |
| **SQL Injection (SQLi)** | `UNION`, `SELECT`, `OR 1=1`, `' OR '`, `--` in query params / logs | Count >= 1 in 1 min | `DevSecOps-SQLInjection-Alarm` |
| **Cross-Site Scripting (XSS)** | `<script>`, `javascript:`, `onerror=`, `onload=` | Count >= 1 in 1 min | `DevSecOps-XSSAttack-Alarm` |
| **Brute-Force Login** | HTTP Status `401 Unauthorized` or failed login count | Count >= 10 in 5 mins | `DevSecOps-BruteForce-Alarm` |
| **SSH Auth Failures** | `Failed password` or `Invalid user` in syslog | Count >= 3 in 1 min | `DevSecOps-SSHAuthFailure-Alarm` |

---

## 🧪 Controlled Security Testing & Verification

To execute safe security test simulations:
```bash
# Run attack simulation against local or staging target
./security/test-attack-simulation.sh http://<TARGET_SERVER_IP>
```
