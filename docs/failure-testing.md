# Chaos Engineering & Failure Resiliency Testing

## 1. Overview & Verification Strategy
To validate system resiliency under failure conditions, five explicit failure scenarios were simulated against the pipeline and production environment.

## 2. Tested Chaos & Failure Scenarios

### Scenario 1: Unit Test Failure (Quality Gate 1)
- **Injection:** Introduced a breaking assertion in `backend/ProductAPI.Tests/ProductTests.cs` (`Price == 999.99m`).
- **Expected Outcome:** Pipeline aborts at Stage 2 (`Unit Tests`). Zero artifacts built.
- **Verification:** Observed on Jenkins Build #5 (Status: FAILED / RED).

### Scenario 2: Hardcoded Secret / Credential Leak (Quality Gate 2)
- **Injection:** Inserted an exposed credential string into `backend/appsettings.json`.
- **Expected Outcome:** Gitleaks flags high-entropy secret at Stage 3 (`Security Scan`). Deployment halted.
- **Verification:** Observed on Jenkins Build #6 (Status: FAILED / RED).

### Scenario 3: Bad Release Binary / Health Probe Failure (Chaos Test)
- **Injection:** Deployed a release payload with invalid database credentials causing `/health` endpoint to return HTTP 500.
- **Expected Outcome:** Stage 9 (`Automated Health Gate`) retry probe fails. Automated fallback catches exception and restores traffic to the previous active environment (`switch-traffic.sh`).
- **Verification:** Application remained 100% available on live port without user downtime.

### Scenario 4: Database Unavailability during Pre-Flight Gate
- **Injection:** Temporarily stopped PostgreSQL service on the production host (`sudo systemctl stop postgresql`).
- **Expected Outcome:** Pipeline Stage 4 (`Database Pre-flight Check`) fails `pg_isready` connection probe and exits with code 1.
- **Verification:** Pipeline terminates before executing release build or migrations.

### Scenario 5: Database Migration Failure & Automatic Rollback
- **Injection:** Injected corrupt SQL syntax into migration script `002_corrupt_schema.sql`.
- **Expected Outcome:** Migration script returns non-zero exit status; pipeline aborts before traffic switch; database restored from pre-deployment backup.
- **Verification:** System state rollbacks cleanly and production remains unaffected.
