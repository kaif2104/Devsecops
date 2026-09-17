# Blue-Green Deployment & Automated Rollback Architecture
## 1. Overview
Our production deployment utilizes an active-standby Blue-Green architecture to achieve zero downtime and instant recovery:
- **BLUE Slot:** Port `5001` (`/var/www/blue`), controlled by `productapi-blue.service`
- **GREEN Slot:** Port `5002` (`/var/www/green`), controlled by `productapi-green.service`
- **Ingress Controller:** Nginx reverse proxy dynamically routing traffic via `/etc/nginx/conf.d/backend_upstream.conf`
## 2. Deployment Sequence (New Release)
1. **Target Identification:** Identify inactive slot (e.g. if BLUE is active, deploy to GREEN).
2. **Deployment:** Copy newly compiled binaries into `/var/www/green/`.
3. **Boot & Isolated Health Verification:**
   - Start `productapi-green.service` on Port `5002`.
   - Run automated synthetic health probes directly against `http://localhost:5002/health`.
   - Verify HTTP `200 OK` and database connectivity before any production routing.
4. **Traffic Switch:**
   - Execute `/usr/local/bin/switch-traffic.sh green`.
   - Nginx updates upstream to `127.0.0.1:5002` and reloads gracefully (`nginx -s reload`).
## 3. Instant Rollback Procedure
If the post-switch health check fails, or error rates spike:
1. Trigger automated rollback script:
   `sudo /usr/local/bin/switch-traffic.sh blue`
2. In less than 100 milliseconds, Nginx shifts 100% of user traffic back to BLUE on Port `5001`.
3. The previous stable version resumes serving traffic with zero application restart time.
