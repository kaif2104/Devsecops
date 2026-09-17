# System & Pipeline Architecture

## 1. System Topology Overview
The DevSecOps production pipeline implements a complete 2-tier isolated server architecture:
- **CI/CD Control Plane (Jenkins Server):** Executes build automation, unit testing, static application security testing (SAST), secret scanning, and remote orchestration over SSH.
- **Production Host (Web & Database Server):** Runs PostgreSQL (port 5432), Nginx reverse proxy (ports 80/443), and dual systemd application slots (`productapi-blue.service` on port 5001 and `productapi-green.service` on port 5002).

```
   [ Developer ] ---> Git Commit / Push
                            |
                            v
               [ Jenkins Server (13.234.216.249) ]
       +--------------------+--------------------+
       | - Unit Tests (xUnit)                    |
       | - Gitleaks (Secret Scan)                |
       | - Semgrep (SAST Vulnerability Scan)     |
       | - Release Compilation (.NET 8 Publish) |
       +--------------------+--------------------+
                            | SSH / Automated Pipeline
                            v
                [ Web Server (3.7.56.229) ]
       +--------------------+--------------------+
       | Nginx Dynamic Upstream Ingress Switch   |
       |  /               \                      |
       | (Port 5001)     (Port 5002)             |
       | [ Blue Slot ]   [ Green Slot ]          |
       |        \           /                    |
       |       [ PostgreSQL DB ]                 |
       +-----------------------------------------+
```

## 2. End-to-End Pipeline Stages
1. **Checkout:** Clones the target release commit from Git.
2. **Unit Tests Gate:** Executes xUnit testing. Any failed test immediately aborts build execution.
3. **Security Scan Gate (DevSecOps):** Runs Gitleaks for exposed credential detection and Semgrep for code injection/SAST bugs.
4. **Database Pre-flight Check:** Verifies PostgreSQL availability (`pg_isready`) on port 5432 prior to deployment.
5. **Build & Package:** Compiles optimized .NET 8 backend release binaries into `/build-output/backend`.
6. **Pre-Deployment Backup:** Generates timestamped SQL database dumps before making application changes.
7. **Database Migration:** Executes versioned DDL migration scripts against PostgreSQL.
8. **Deploy to Inactive Slot:** Copies release binaries to the idle slot (Blue or Green) and starts the slot service.
9. **Automated Health Probe Gate:** Executes retry probes against `http://127.0.0.1:<PORT>/health`. If health check fails, the pipeline aborts and preserves live traffic on the current active slot.
10. **Traffic Switch:** Dynamically updates Nginx upstream configuration and executes a seamless reload (`nginx -s reload`).
