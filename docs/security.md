# Security & DevSecOps Compliance Strategy

## 1. Shift-Left Security Quality Gates
Security controls are embedded directly into the CI/CD pipeline to prevent vulnerable or compromised code from reaching production:
1. **Secret Leak Detection (Gitleaks):** Scans the entire codebase and commit history for AWS keys, private tokens, passwords, and API credentials. Any detected secret immediately halts the pipeline.
2. **Static Application Security Testing (Semgrep):** Analyzes .NET 8 code for OWASP Top 10 vulnerabilities (SQL injection, hardcoded secrets, weak cryptographic algorithms, unsafe deserialization).
3. **Database Pre-flight Security & Integrity Check:** Ensures database connectivity and authentication state are healthy prior to executing DDL migrations.

## 2. DevSecOps Execution Workflow & Quality Gate Failures
- **Gitleaks Rule Enforcement:** Scans `appsettings.json`, `.cs`, and configuration files.
- **Semgrep Security Rules:** Leverages standard C#/.NET security rulesets.

```bash
# Executed via security/scan.sh in Pipeline Stage 3
gitleaks detect --source . --verbose
semgrep --config=auto backend/
```

### Verified Evidence of Blocked Deployments:
- **Quality Gate Failure 1 (Unit Test Block):** Build #5 failed when a unit test assertion expected `Price == 999.99m`. Pipeline aborted prior to build packaging.
- **Quality Gate Failure 2 (Security Gate Block):** Build #6 failed when an `AWS_SECRET_ACCESS_KEY` high-entropy string was injected into `appsettings.json`. Gitleaks flagged the credential and halted execution.
