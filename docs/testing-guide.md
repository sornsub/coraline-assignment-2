# Local Testing Guide

This guide walks a reviewer through starting the platform locally, verifying every service, and running a complete alert end-to-end test. No real cloud environment or Kubernetes cluster is required.

---

## Prerequisites

| Tool | Minimum version | How to check |
|---|---|---|
| Docker Desktop (or Engine + Compose) | 24.x | `docker --version` |
| Git | 2.x | `git --version` |
| kubectl (optional) | 1.28+ | `kubectl version --client` — only needed for Kustomize validation |

---

## Quick Start (5 minutes)

### 1 — Clone and configure

```bash
git clone https://github.com/sornsub/coraline-assignment-2-temp.git
cd coraline-challenge2

# Create your local .env from the template
cp .env.example .env
```

Open `.env` in any text editor. The only value you need to change for full alert testing is:

```
ALERT_WEBHOOK_URL=https://webhook.site/replace-with-your-webhook-url
```

See [Setting up Webhook.site](#setting-up-webhooksite) below for how to get a real URL.
All other defaults work without changes.

### 2 — Start the stack

```bash
docker compose up --build -d
```

Expected output (last few lines):
```
Container coraline-challenge2-alertmanager-1   Started
Container coraline-challenge2-prometheus-1     Started
Container coraline-challenge2-grafana-1        Started
Container coraline-challenge2-portal-1         Started
```

First build takes 2–4 minutes. Subsequent starts take ~15 seconds.

### 3 — Verify all services are running

```bash
docker compose ps
```

Expected: 8 containers, all `Up` or `Up (healthy)`.

```
NAME                                   STATUS
coraline-challenge2-airflow-1          Up
coraline-challenge2-alertmanager-1     Up
coraline-challenge2-api-1              Up
coraline-challenge2-blackbox-exporter-1  Up
coraline-challenge2-grafana-1          Up
coraline-challenge2-notebook-lab-1     Up (healthy)
coraline-challenge2-portal-1           Up
coraline-challenge2-prometheus-1       Up
```

---

## Expected Service URLs

Open each URL in a browser after `docker compose up`:

| Service | URL | Credentials |
|---|---|---|
| **Portal** | http://localhost:8080 | none |
| **API health** | http://localhost:8000/health | none |
| **API source catalog** | http://localhost:8000/api/v1/sources | none |
| **Airflow** | http://localhost:8081 | admin / change-me-local-only |
| **Notebook** | http://localhost:8888 | none (auth disabled for demo) |
| **Prometheus** | http://localhost:9090 | none |
| **Prometheus alerts** | http://localhost:9090/alerts | none |
| **Prometheus targets** | http://localhost:9090/targets | none |
| **Alertmanager** | http://localhost:9093 | none |
| **Grafana** | http://localhost:3000 | admin / admin |
| **Webhook.site** | your unique URL | browser only |

---

## Setting Up Webhook.site

Webhook.site gives you a free public URL that captures any HTTP POST sent to it — no account needed.

**Steps:**

1. Open **https://webhook.site** in your browser.
2. A unique URL appears automatically at the top of the page, for example:
   ```
   https://webhook.site/2c5b713a-5aa0-4f1d-bca3-c84240d53398
   ```
3. **Copy that URL exactly** — this is the listener URL, not the browser view URL.

   > ⚠️ **Common mistake:** Do not copy the browser's address bar URL which contains `#!/view/`. That is the Webhook.site dashboard URL, not the webhook receiver endpoint.
   >
   > ✅ **Correct format:** `https://webhook.site/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`  
   > ❌ **Wrong format:** `https://webhook.site/#!/view/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

4. Paste it into `.env`:
   ```
   ALERT_WEBHOOK_URL=https://webhook.site/your-unique-id-here
   ```
5. Restart Alertmanager to pick up the new value:
   ```bash
   docker compose restart alertmanager
   ```

> **Security:** Never commit `.env` to the repository. The `.gitignore` already excludes it. The `.env.example` file contains only placeholder values and is safe to commit.

---

## Expected Command Output

Run these commands after `docker compose up --build -d` to verify each service is responding correctly.

### Portal health
```bash
curl http://localhost:8080/health
```
Expected:
```json
{"status":"ok","service":"atlas-portal"}
```

### API health
```bash
curl http://localhost:8000/health
```
Expected:
```json
{"status":"ok","service":"orion-api"}
```

### API readiness
```bash
curl http://localhost:8000/ready
```
Expected:
```json
{"status":"ready","environment":"local"}
```

### API source catalog
```bash
curl http://localhost:8000/api/v1/sources
```
Expected:
```json
{
  "sources": [
    {
      "name": "cloud-analytics-db",
      "type": "cloud-database",
      "connectivity": "private endpoint or VPC peering",
      "secretRef": "managed externally"
    },
    {
      "name": "on-prem-reporting-db",
      "type": "on-premise-database",
      "connectivity": "VPN or private interconnect",
      "secretRef": "managed externally"
    },
    {
      "name": "object-storage-lake",
      "type": "object-storage",
      "connectivity": "cloud IAM role or workload identity",
      "secretRef": "managed externally"
    }
  ]
}
```

### Prometheus ready
```bash
curl http://localhost:9090/-/ready
```
Expected:
```
Prometheus Server is Ready.
```

### Alertmanager ready
```bash
curl http://localhost:9093/-/ready
```
Expected:
```
OK
```

### Grafana health
```bash
curl http://localhost:3000/api/health
```
Expected:
```json
{"commit":"13173c9874af312fe75545f52aa6539af02076ac","database":"ok","version":"11.1.4"}
```

---

## Grafana Dashboard Walkthrough

1. Open **http://localhost:3000**
2. Log in: username `admin`, password `admin`
3. Click **Dashboards** in the left sidebar
4. Open **Atlas Platform → Atlas Platform — Service Availability**

**What to expect:**

| Panel | Expected state |
|---|---|
| **Prometheus** stat panel | Green — UP |
| **atlas-portal** stat panel | Green — UP |
| **orion-api** stat panel | Green — UP |
| **airflow (probe)** stat panel | Green — UP |
| **Firing Alerts** stat panel | Green — None |
| **Service Status Over Time** timeseries | All lines at 1 |

> If atlas-portal or orion-api shows DOWN immediately after startup, wait 30 seconds and refresh — Prometheus needs one scrape cycle (15 seconds) to detect the services.

---

## Prometheus Targets Walkthrough

1. Open **http://localhost:9090/targets**

**What to expect — all targets should show State: UP:**

| Job | Instance | Expected state |
|---|---|---|
| `prometheus` | `localhost:9090` | UP |
| `atlas-portal` | `portal:8080` | UP |
| `orion-api` | `api:8000` | UP |
| `airflow-health` | `http://airflow:8080/health` | UP |

---

## Alert End-to-End Test

This test simulates a service outage, observes the alert firing, and verifies the webhook notification is received.

### Step 1 — Stop atlas-portal

```bash
docker compose stop portal
```

### Step 2 — Watch the alert move through states

Open **http://localhost:9090/alerts** in your browser.

| Time after stop | Expected state |
|---|---|
| 0–15 seconds | Target disappears from `/targets` |
| 15–60 seconds | Alert shows **PENDING** |
| ~70 seconds | Alert shows **FIRING** |

> The `for: 1m` duration in `prometheus/alert-rules.yml` means the alert must be continuously failing for 1 minute before transitioning to FIRING.

### Step 3 — Verify in Alertmanager

Open **http://localhost:9093**

Expected: `AtlasPortalDown` appears as an active alert with:
- Labels: `severity=critical`, `service=atlas-portal`, `team=platform`
- State: `active`

### Step 4 — Check Webhook.site

Open your Webhook.site URL in the browser.

Expected: A new POST request appears in the inbox with a JSON body containing:

```json
{
  "receiver": "webhook",
  "status": "firing",
  "alerts": [
    {
      "status": "firing",
      "labels": {
        "alertname": "AtlasPortalDown",
        "severity": "critical",
        "service": "atlas-portal",
        "team": "platform"
      },
      "annotations": {
        "summary": "atlas-portal is DOWN",
        "description": "Prometheus cannot scrape atlas-portal /metrics...",
        "runbook": "Diagnose: docker compose ps portal..."
      }
    }
  ]
}
```

### Step 5 — Recover and verify resolution

```bash
docker compose start portal
```

Within 30 seconds:
- Prometheus target turns UP
- Alert disappears from `/alerts`
- Alertmanager clears the alert
- Webhook.site receives a second POST with `"status": "resolved"`

---

## Kubernetes Manifest Validation (no cluster required)

These commands validate the Kustomize overlays offline:

```bash
kubectl kustomize k8s/overlays/dev
kubectl kustomize k8s/overlays/staging
kubectl kustomize k8s/overlays/prod
```

Expected: YAML output with no errors. Each command should print the fully-rendered Kubernetes manifests for that environment (Deployments, Services, ConfigMaps, Namespace, Ingress).

---

## Unit Tests

### atlas-portal (Node.js)

```bash
cd apps/atlas-portal
npm install
npm run lint
npm test
```

Expected output (last lines):
```
▶ atlas-portal test suite
✔ test harness check (N ms)
ℹ tests 1
ℹ pass 1
ℹ fail 0
```

### orion-api (Python)

```bash
cd apps/orion-api
pip install -r requirements.txt
pytest -v
```

Expected output:
```
tests/test_main.py::test_health PASSED
tests/test_main.py::test_no_password_in_sources PASSED

2 passed in N.Ns
```

---

## Troubleshooting

### Webhook.site receives nothing

| Check | Action |
|---|---|
| Is `ALERT_WEBHOOK_URL` set? | Run `docker compose exec alertmanager cat /tmp/alertmanager.yml` — the URL should appear under `url:` |
| Is the URL the listener, not the view? | URL must be `https://webhook.site/UUID` — not the `#!/view/` browser URL |
| Did you restart Alertmanager after editing `.env`? | Run `docker compose restart alertmanager` |
| Has the alert moved to FIRING? | Check `http://localhost:9090/alerts` — alert must show FIRING, not PENDING |
| Wait for `group_wait`? | Alertmanager batches alerts — default `group_wait` is 30 seconds after FIRING |

### Alertmanager is not ready (`curl localhost:9093/-/ready` fails)

```bash
# Check if the container started
docker compose ps alertmanager

# Check startup logs for config errors
docker compose logs alertmanager
```

A common startup error is a bad `ALERT_WEBHOOK_URL` substitution. Run:
```bash
docker compose exec alertmanager cat /tmp/alertmanager.yml
```
The URL line should read `url: 'https://webhook.site/...'` — not `url: 'WEBHOOK_URL_PLACEHOLDER'`.

### Prometheus target shows DOWN

```bash
# Check if the service container is running
docker compose ps

# Check the specific service's logs
docker compose logs portal   # or api, airflow
```

If the service is running but the target is DOWN, wait one 15-second scrape cycle and refresh `http://localhost:9090/targets`.

### Grafana dashboard is empty or shows "No data"

1. Confirm Prometheus is running: `curl http://localhost:9090/-/ready`
2. Check the datasource: Grafana → Connections → Data sources → Prometheus Local → Test
3. Wait 30 seconds after startup — Prometheus needs a scrape cycle before metrics appear

### `.env` is not loaded / wrong value is used

Docker Compose reads `.env` from the directory where `docker compose` is run. Make sure:
- The file is named exactly `.env` (not `.env.local`, not `.env.copy`)
- You run `docker compose` commands from the repo root (`coraline-challenge2/`)
- After editing `.env`, restart affected services:
  ```bash
  docker compose restart alertmanager
  ```

### CRLF warning on Windows Git

```
warning: in the working copy of 'README.md', LF will be replaced by CRLF
```

This is cosmetic — Git is normalising line endings on Windows. It does not affect functionality. The warning appears when staging files; it can be safely ignored for this demo.

To suppress it permanently:
```bash
git config core.autocrlf true
```

---

## Reviewer Checklist

Use this checklist before submission.

### Local stack

- [ ] `docker compose up --build -d` completes without errors
- [ ] `docker compose ps` shows 8 containers all `Up`
- [ ] `curl http://localhost:8080/health` returns `{"status":"ok","service":"atlas-portal"}`
- [ ] `curl http://localhost:8000/health` returns `{"status":"ok","service":"orion-api"}`
- [ ] `curl http://localhost:8000/ready` returns `{"status":"ready","environment":"local"}`
- [ ] `curl http://localhost:8000/api/v1/sources` returns 3 data sources
- [ ] `curl http://localhost:9090/-/ready` returns `Prometheus Server is Ready.`
- [ ] `curl http://localhost:9093/-/ready` returns `OK`
- [ ] `curl http://localhost:3000/api/health` returns `"database":"ok"`

### Monitoring

- [ ] Grafana dashboard loads at http://localhost:3000 (admin / admin)
- [ ] All 4 service panels show green / UP
- [ ] Firing Alerts panel shows "None"
- [ ] Prometheus targets page shows all 4 jobs as UP

### Alert test

- [ ] `docker compose stop portal` triggers `AtlasPortalDown` within 70 seconds
- [ ] Alert appears as FIRING at http://localhost:9090/alerts
- [ ] Alert appears in Alertmanager at http://localhost:9093
- [ ] Webhook.site inbox receives the POST notification
- [ ] `docker compose start portal` clears the alert
- [ ] Webhook.site receives a resolved notification

### Kubernetes validation

- [ ] `kubectl kustomize k8s/overlays/dev` renders without errors
- [ ] `kubectl kustomize k8s/overlays/staging` renders without errors
- [ ] `kubectl kustomize k8s/overlays/prod` renders without errors

### Unit tests

- [ ] `cd apps/atlas-portal && npm test` passes
- [ ] `cd apps/orion-api && pytest` passes (2 tests)

### CI/CD

- [ ] GitHub Actions workflow passes on the `main` branch
- [ ] No `.env` file is committed to the repository

### Security

- [ ] `git status` shows `.env` as untracked (not staged or committed)
- [ ] `git log --all --full-history -- .env` returns no commits
