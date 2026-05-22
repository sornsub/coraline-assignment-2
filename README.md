# Coraline Challenge 2: Internal Web Application Platform

## Project Overview

This repository demonstrates a **platform engineering design** for an internal web application that aggregates data from multiple sources and presents results through a unified web portal. It is an **assignment-ready demo** — not a production system.

The design covers:

- A multi-service application stack deployed on Kubernetes
- Environment separation using Kustomize overlays (dev / staging / prod)
- A CI/CD pipeline with automated testing, image scanning, and GitOps-style deployment
- Operational readiness: health checks, readiness probes, and observability design

> `app2.zip` was used as an architecture reference during development only and is not included in this repository. This project does not copy proprietary names, images, hosts, IPs, passwords, or secrets from that archive.

---

## Documentation Index

| Document | Description |
|---|---|
| [docs/architecture.md](docs/architecture.md) | System architecture diagrams, CI/CD flow, and release promotion |
| [docs/cicd-pipeline.md](docs/cicd-pipeline.md) | Full CI/CD pipeline stages, branch mapping, image tagging, GitOps handoff |
| [docs/environments.md](docs/environments.md) | dev / staging / prod environment strategy and Kustomize overlay breakdown |
| [docs/testing-guide.md](docs/testing-guide.md) | Step-by-step local test guide, expected outputs, alert test, troubleshooting |
| [docs/images/README.md](docs/images/README.md) | Screenshot capture guide for submission evidence |
| [monitoring/README.md](monitoring/README.md) | Observability design: Prometheus, Grafana, Alertmanager, logging approach |
| [monitoring/prometheus-rules.yaml](monitoring/prometheus-rules.yaml) | Example PrometheusRule CRD with 5 alert definitions (design evidence) |

---

## Quick Start

> Full step-by-step guide with expected outputs, alert test, and troubleshooting: **[docs/testing-guide.md](docs/testing-guide.md)**

```bash
# 1. Copy environment template
cp .env.example .env
# Edit .env — set ALERT_WEBHOOK_URL to your Webhook.site URL (optional for basic test)

# 2. Build and start all 8 services
docker compose up --build -d

# 3. Verify all containers are running
docker compose ps

# 4. Open the portal
open http://localhost:8080        # macOS
# or: start http://localhost:8080  # Windows
```

| Service | URL |
|---|---|
| Portal | http://localhost:8080 |
| API health | http://localhost:8000/health |
| Prometheus | http://localhost:9090/targets |
| Grafana | http://localhost:3000 (admin / admin) |
| Alertmanager | http://localhost:9093 |

**Success looks like:** `docker compose ps` shows 8 containers `Up`, Grafana dashboard shows all 4 service panels green.

---

## Architecture Overview

The platform consists of four internal services behind an Ingress controller. External data sources are reached through private network paths. Monitoring and logging are designed as platform-level concerns.

```
Internet boundary
  └─ Ingress (nginx)
       ├─ / → atlas-portal  (web portal)
       └─ /api → orion-api  (API service)
                    │
                    └─ External data sources via private network
                       (Cloud DB, On-Prem DB, Object Storage, External API)

Workflow: Apache Airflow (scheduled data sync DAGs)
Observability (design): Prometheus → Grafana, Alertmanager, Fluent Bit / Loki
```

For the full diagram see **[docs/architecture.md](docs/architecture.md)**.

---

## Component and Service Map

| Service | Stack | Port | Purpose | Health endpoint |
|---|---|---|---|---|
| `atlas-portal` | Node.js / Express | 8080 | Web portal — service cards, environment display, links to platform tools | `/health` |
| `orion-api` | Python / FastAPI | 8000 | API service — data source catalog (`/api/v1/sources`), readiness check | `/health`, `/ready` |
| `airflow` | Apache Airflow | 8081 | Workflow orchestration — scheduled external data sync DAGs | `/health` |
| `notebook-lab` | JupyterLab | 8888 | Notebook environment — ad hoc data exploration | — |

---

## Local Development Setup

### Requirements

- Docker Desktop (or Docker Engine + Compose plugin)
- Git

### Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/sornsub/coraline-assignment-2-temp.git
   cd coraline-challenge2
   ```

2. (Optional) Review placeholder environment variables:
   ```bash
   cat .env.example
   ```

3. Start the full local stack:
   ```bash
   docker compose up --build
   ```

4. Access services:

   | Service | Local URL | Notes |
   |---|---|---|
   | Portal | `http://localhost:8080` | |
   | API source catalog | `http://localhost:8000/api/v1/sources` | |
   | API health | `http://localhost:8000/health` | |
   | Airflow | `http://localhost:8081` | |
   | Notebook | `http://localhost:8888` | |
   | Prometheus | `http://localhost:9090` | App scrape targets show down until Phase 2 instrumentation |
   | Grafana | `http://localhost:3000` | Credentials: admin / admin (demo only) — dashboard auto-loads under Atlas Platform |

5. Stop the stack:
   ```bash
   docker compose down
   ```

### Notes

- The Airflow service uses `standalone` mode for local demo only. The admin password is a placeholder value in `docker-compose.yaml` and is overridable with `AIRFLOW_ADMIN_PASSWORD`.
- The notebook service disables token authentication for local review only. Production must add authentication and network controls.
- See `.env.example` for all configurable environment variable names.

---

## Testing Guide

### Run tests locally

**atlas-portal (Node.js):**
```bash
cd apps/atlas-portal
npm install
npm run lint
npm test
```

**orion-api (Python):**
```bash
cd apps/orion-api
pip install -r requirements.txt
pytest
```

### What the tests cover

| Service | Test file | What is verified |
|---|---|---|
| `atlas-portal` | `apps/atlas-portal/src/server.test.js` | Test harness smoke check |
| `orion-api` | `apps/orion-api/tests/test_main.py` | `/health` response; no password literals in data source definitions |

### Validate Kubernetes manifests (no cluster required)

```bash
kubectl kustomize k8s/overlays/dev
kubectl kustomize k8s/overlays/staging
kubectl kustomize k8s/overlays/prod
```

This confirms all Kustomize patches apply cleanly and all three overlay configurations are valid.

### Tests in CI

All tests and Kustomize validations run automatically on every pull request and push to `dev`, `staging`, and `main`. Pull requests cannot be merged if any test or validation step fails. See [docs/cicd-pipeline.md](docs/cicd-pipeline.md).

---

## Environment Strategy

Three environments — **dev**, **staging**, and **prod** — are separated by Kubernetes namespace and Kustomize overlay.

| Environment | Branch | Namespace | Ingress host | Purpose |
|---|---|---|---|---|
| dev | `dev` | `atlas-dev` | `atlas-dev.example.internal` | Active development, frequent deployments |
| staging | `staging` | `atlas-staging` | `atlas-staging.example.internal` | Integration testing, pre-release validation |
| prod | `main` | `atlas-prod` | `atlas.example.internal` | Live internal users, high availability |

Key differences across environments:

| Setting | dev | staging | prod |
|---|---|---|---|
| Replicas (portal) | 1 | 1 | 3 |
| Replicas (API) | 1 | 1 | 3 |
| CPU request (portal / API) | 50m / 50m | 100m / 100m | 150m / 200m |
| CPU limit (portal / API) | 200m / 250m | 300m / 500m | 500m / 1000m |
| Memory request (portal / API) | 64Mi / 96Mi | 96Mi / 128Mi | 128Mi / 256Mi |
| Memory limit (portal / API) | 128Mi / 256Mi | 192Mi / 384Mi | 256Mi / 512Mi |

For the full breakdown of config, secrets, image tags, and Kustomize structure, see **[docs/environments.md](docs/environments.md)**.

---

## Deployment Approach

### Kubernetes with Kustomize

Manifests are organised as a shared base layer with environment-specific overlay patches:

```
k8s/
├── base/          # Shared: Namespace, ConfigMap, Deployments, Services, Ingress
└── overlays/
    ├── dev/       # Patches: namespace, image tag, replicas, config, ingress host
    ├── staging/
    └── prod/
```

**Validate (no cluster required):**
```bash
kubectl kustomize k8s/overlays/dev
kubectl kustomize k8s/overlays/staging
kubectl kustomize k8s/overlays/prod
```

**Apply to a cluster:**
```bash
kubectl apply -k k8s/overlays/dev
kubectl apply -k k8s/overlays/staging
kubectl apply -k k8s/overlays/prod
```

### GitOps (recommended)

A GitOps controller (Argo CD or Flux) watches the appropriate branch and overlay and applies changes automatically after CI passes and any required approvals are granted. Manual `kubectl apply -k` is the documented fallback.

### Airflow in production

The Kubernetes Airflow manifest is a single-pod `standalone` demo. Production should use the official Apache Airflow Helm chart with a production-grade metadata database, executor configuration (Celery or Kubernetes executor), DAG distribution mechanism (Git sync or PVC), and external secret management.

---

## CI/CD Pipeline

The pipeline is defined in `.github/workflows/ci-cd.yaml` and runs on every push and pull request to `dev`, `staging`, and `main`.

### Three jobs

| Job | Triggered by | What it does |
|---|---|---|
| `test-and-validate` | All events (PR + push) | Tests both services, lints portal, validates all three Kustomize overlays |
| `build-scan-push` | Push only | Builds Docker images, scans with Trivy (CRITICAL + HIGH), pushes to GHCR |
| `deployment-plan` | Push only | Documents deployment target; hands off to GitOps controller |

### Image tagging

| Branch | Image tag |
|---|---|
| `dev` | `:dev` |
| `staging` | `:staging` |
| `main` | `:prod` |

Images are published to `ghcr.io/<org>/atlas-portal` and `ghcr.io/<org>/orion-api` using the built-in `GITHUB_TOKEN`. No additional registry credential is required.

For full pipeline stages, diagrams, and GitOps handoff detail, see **[docs/cicd-pipeline.md](docs/cicd-pipeline.md)**.

---

## Release Promotion Flow

Releases move through environments by pull request:

```
dev branch  ──[PR]──►  staging branch  ──[PR + approval]──►  main branch
     │                        │                                    │
 atlas-dev                atlas-staging                        atlas-prod
```

Each promotion step:
1. Opens a pull request — peer review is required
2. CI runs the full test / build / scan / validate pipeline on the PR
3. On merge, the GitOps controller (or `kubectl apply -k`) deploys to the target environment
4. Production promotion includes a recommended manual approval gate via GitHub Environments

No changes skip staging. Emergency patches follow the same path at an accelerated pace.

---

## Configuration and Secret Management

### Non-sensitive configuration

Stored in Kubernetes ConfigMaps, patched per environment by Kustomize overlays.

| Key | Example value | Where it is used |
|---|---|---|
| `APP_ENV` | `dev`, `staging`, `prod` | All services — environment name |
| `API_URL` | `http://orion-api:8000` | Portal — calls the API service |
| `AIRFLOW_URL` | `http://airflow:8080` | Portal — Airflow card link |
| `GRAFANA_URL` | `https://grafana.example.internal` | Portal — monitoring card link |
| `SERVICE_LINKS_JSON` | JSON array of card definitions | Portal — builds service card UI |

Base ConfigMap: `k8s/base/configmap.yaml`. Environment patches: `k8s/overlays/<env>/config-patch.yaml`.

### Secrets

Secrets are **never stored in ConfigMaps, application images, or this repository**.

| File | Purpose |
|---|---|
| `.env.example` | Placeholder variable names for local development — no real values |
| `k8s/base/secret-example.yaml` | Template showing the expected Kubernetes Secret structure — placeholder values only |

**For production, use one of:**
- **External Secrets Operator** — syncs from AWS Secrets Manager, Azure Key Vault, GCP Secret Manager, or HashiCorp Vault
- **Sealed Secrets** — encrypts secrets for safe GitOps storage
- **Workload identity** (IRSA / Workload Identity Federation) — removes static credentials for cloud resources

Applications reference secrets via `secretRef` in Deployment specs. Real values are injected by the secrets management system at pod startup.

---

## External System Connectivity

The API (`orion-api`) and Airflow connect to external data sources. No credentials are hardcoded in this repository.

| External system | Connection method (design) | Authentication |
|---|---|---|
| Cloud database | Private endpoint / VPC peering | IAM role or workload identity |
| On-premise database | VPN / Direct Connect / ExpressRoute | Credential injected via External Secrets Operator |
| Object storage | Cloud-native SDK | IRSA / Workload Identity Federation |
| External API | HTTPS over private network | API token from Secrets Manager |

Network controls:
- Kubernetes `NetworkPolicy` restricts pod-to-pod and pod-to-external traffic
- Firewall rules and DNS are managed at the cluster boundary
- TLS is required for all external connections
- Audit logging captures all external data access events

Data source stubs are defined in `apps/orion-api/app/main.py` at `GET /api/v1/sources` for demonstration purposes.

---

## Monitoring, Logging, Health Checks, and Alerting

### Health check endpoints

All main services expose health endpoints. Kubernetes `readinessProbe` and `livenessProbe` are defined in `k8s/base/<service>/deployment.yaml` for each service.

| Service | Endpoint | Probe type |
|---|---|---|
| `atlas-portal` | `/health` | Readiness + Liveness |
| `orion-api` | `/health` | Liveness |
| `orion-api` | `/ready` | Readiness |
| `airflow` | `/health` | Startup + Readiness + Liveness |

### Metrics — design intent

- Services expose Prometheus-compatible `/metrics` endpoints where available
- Prometheus scrapes pods via service annotation or `ServiceMonitor` CRDs
- Grafana dashboards cover: request rate, error rate, latency (p50 / p95 / p99), pod restarts, CPU / memory, Airflow DAG run status
- The `GRAFANA_URL` placeholder in the ConfigMap links the portal service card to the Grafana dashboard

### Logging — design intent

- All services write structured logs to **stdout / stderr**
- Cluster logging stack (Fluent Bit + OpenSearch, Loki, or a cloud logging service) collects and indexes pod logs
- Audit logs for external data access are retained separately

### Alerting — design intent

| Alert | Condition | Channel |
|---|---|---|
| Pod not ready | Readiness probe failing > 2 min | PagerDuty / Slack |
| High error rate | HTTP 5xx rate > 5% over 5 min | Slack |
| Airflow DAG failure | DAG run state = failed | Slack |
| Resource pressure | CPU or memory > 90% sustained | PagerDuty |

Alerts are routed via Alertmanager to Slack (low-severity) and PagerDuty (high-severity). The design intent is documented here and in `docs/architecture.md`.

### Alertmanager — local Docker Compose

Alertmanager is running locally via `docker compose up`. Alert rules are defined in `prometheus/alert-rules.yml`. Notifications are forwarded to a webhook URL configured in `.env`.

**Alert rules (fire after 1 minute down):**

| Alert | Expression | Service |
|---|---|---|
| `AtlasPortalDown` | `up{job="atlas-portal"} == 0` | atlas-portal |
| `OrionApiDown` | `up{job="orion-api"} == 0` | orion-api |
| `AirflowHealthDown` | `probe_success{job="airflow-health"} == 0` | airflow |

**Set up Webhook.site for local testing:**

1. Open [https://webhook.site](https://webhook.site) — a unique URL is auto-generated for you.
2. Copy the URL shown (e.g., `https://webhook.site/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`).
3. Add it to your local `.env`:
   ```bash
   cp .env.example .env
   # Edit .env and set:
   # ALERT_WEBHOOK_URL=https://webhook.site/your-unique-id
   ```
4. Start or restart the stack:
   ```bash
   docker compose up -d
   ```

**Test an alert end-to-end:**

```bash
# Stop atlas-portal to trigger AtlasPortalDown
docker compose stop portal

# Wait 60–90 seconds for the alert to move from PENDING to FIRING
# Check Prometheus alert state:
open http://localhost:9090/alerts

# Check Alertmanager (should show the firing alert):
open http://localhost:9093

# Check Webhook.site — a POST notification should arrive with the alert payload

# Recover and verify the resolved notification:
docker compose start portal
```

**Alertmanager UI:** `http://localhost:9093`
**Prometheus alerts page:** `http://localhost:9090/alerts`

---

## Assumptions and Limitations

| Item | Note |
|---|---|
| Demo scope | Assignment-ready demo, not a production system |
| Ingress hosts | Placeholder values under `example.internal` — real DNS must be configured |
| Image registry | GHCR placeholder names in K8s manifests — real registry paths must be supplied |
| Cluster | No real Kubernetes cluster is needed to review this repo; `kubectl kustomize` validates manifests offline |
| Trivy | Configured with `exit-code: 0` — findings are reported but do not block the build; tighten for production |
| Notebook auth | Token auth disabled for local review only; production must add auth and network controls |
| Airflow | Single-pod `standalone` mode for demo; production must use the official Helm chart |
| Monitoring runtime | Prometheus, Grafana, and Alertmanager run locally via `docker compose up`; K8s production observability stack is outside assignment scope |
| Secret backends | External Secrets Operator, Vault, or equivalent must be provisioned by the deploying organisation |
| `app2.zip` | Used as architecture reference during development only; not included in this repository |

---

## Screenshots

> Screenshots are not committed to the repository.  
> Capture them after local verification and save to `docs/images/` before submission.  
> See **[docs/images/README.md](docs/images/README.md)** for exact capture instructions.

### Atlas Portal
**[Screenshot needed — save as `docs/images/portal.png`]**  
*Open http://localhost:8080. Capture the portal page showing all 4 service cards: API Service, Apache Airflow, Notebook Service, Monitoring/Grafana.*

![Atlas Portal](docs/images/portal.png)

### Grafana — All Services UP
**[Screenshot needed — save as `docs/images/grafana-service-availability.png`]**  
*Open http://localhost:3000 → Dashboards → Atlas Platform. Capture all 4 stat panels green and Firing Alerts showing "None".*

![Grafana service availability dashboard](docs/images/grafana-service-availability.png)

### Prometheus Targets
**[Screenshot needed — save as `docs/images/prometheus-targets.png`]**  
*Open http://localhost:9090/targets. Capture all 4 jobs (prometheus, atlas-portal, orion-api, airflow-health) in State=UP.*

![Prometheus scrape targets all UP](docs/images/prometheus-targets.png)

### Prometheus Alerts — AtlasPortalDown Firing
**[Screenshot needed — save as `docs/images/prometheus-alerts.png`]**  
*Run `docker compose stop portal`, wait 70 seconds, then open http://localhost:9090/alerts. Capture AtlasPortalDown in FIRING state.*

![Prometheus alert firing](docs/images/prometheus-alerts.png)

### Alertmanager — Active Alert
**[Screenshot needed — save as `docs/images/alertmanager-alert.png`]**  
*Open http://localhost:9093 after the alert fires. Capture AtlasPortalDown as an active alert routed to the webhook receiver.*

![Alertmanager active alert](docs/images/alertmanager-alert.png)

### Webhook.site — Notification Received
**[Screenshot needed — save as `docs/images/webhook-notification.png`]**  
*Open your Webhook.site URL after the alert fires. Capture the POST request in the inbox showing the JSON alert payload.*

![Webhook.site notification received](docs/images/webhook-notification.png)

### GitHub Actions — Passing
**[Screenshot needed — save as `docs/images/github-actions.png`]**  
*Open the Actions tab on the GitHub repository. Capture the latest workflow run on `main` with all jobs passing.*

![GitHub Actions workflow passing](docs/images/github-actions.png)

---

## Reviewer Checklist

Run through this checklist to confirm the submission is complete.

### Local stack
- [ ] `docker compose up --build -d` completes without errors
- [ ] `docker compose ps` shows 8 containers all `Up`
- [ ] `curl http://localhost:8080/health` → `{"status":"ok","service":"atlas-portal"}`
- [ ] `curl http://localhost:8000/health` → `{"status":"ok","service":"orion-api"}`
- [ ] `curl http://localhost:8000/api/v1/sources` → 3 data sources returned
- [ ] `curl http://localhost:9090/-/ready` → `Prometheus Server is Ready.`
- [ ] `curl http://localhost:9093/-/ready` → `OK`

### Monitoring
- [ ] Grafana dashboard loads at http://localhost:3000
- [ ] All 4 service stat panels show green / UP
- [ ] Prometheus targets page shows all 4 jobs UP
- [ ] Alert test: `docker compose stop portal` triggers `AtlasPortalDown` within 70 seconds
- [ ] Webhook.site receives POST notification (requires `ALERT_WEBHOOK_URL` in `.env`)

### Kubernetes
- [ ] `kubectl kustomize k8s/overlays/dev` renders without errors
- [ ] `kubectl kustomize k8s/overlays/staging` renders without errors
- [ ] `kubectl kustomize k8s/overlays/prod` renders without errors

### CI/CD
- [ ] GitHub Actions workflow passes on the `main` branch
- [ ] No `.env` file is committed (`git status` shows `.env` as untracked or ignored)

---

## Folder Structure

```text
.
├── .github/workflows/ci-cd.yaml     # GitHub Actions CI/CD pipeline
├── apps/
│   ├── atlas-portal/                 # Node.js / Express web portal
│   └── orion-api/                    # Python / FastAPI API service
├── airflow/dags/                     # Sample Airflow DAG
├── docs/
│   ├── architecture.md               # System architecture diagrams
│   ├── cicd-pipeline.md              # CI/CD pipeline documentation
│   ├── environments.md               # Environment strategy documentation
│   ├── testing-guide.md              # Step-by-step local test guide
│   └── images/README.md              # Screenshot capture guide
├── k8s/
│   ├── base/                         # Shared Kubernetes resources
│   └── overlays/dev|staging|prod/    # Environment-specific Kustomize patches
├── monitoring/
│   ├── prometheus-rules.yaml         # Example PrometheusRule CRD (5 alert rules)
│   └── README.md                     # Observability design documentation
├── alertmanager/
│   ├── alertmanager.yml.template     # Alertmanager config template (WEBHOOK_URL_PLACEHOLDER)
│   └── entrypoint.sh                 # sed substitution + Alertmanager startup script
├── prometheus/
│   ├── prometheus.yml                # Prometheus scrape config and alerting config
│   ├── alert-rules.yml               # Alert rules: AtlasPortalDown, OrionApiDown, AirflowHealthDown
│   └── blackbox.yml                  # Blackbox exporter HTTP probe module
├── grafana/
│   ├── provisioning/                 # Auto-provisioned datasource and dashboard provider
│   └── dashboards/                   # Atlas Platform — Service Availability dashboard JSON
├── .env.example                      # Placeholder local environment variables (safe to commit)
├── .gitignore                        # Ignores .env, node_modules/, .claude/, archives
└── docker-compose.yaml               # Local review stack (8 services)
```
