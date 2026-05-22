# Architecture

## System Architecture

The platform runs four services inside a Kubernetes cluster. All inbound traffic passes through an Ingress controller. The API service and Airflow connect to external data sources over private network paths. Monitoring and logging components observe all services from within the cluster.

```mermaid
flowchart LR
  User["Internal User"]

  subgraph Cluster["Kubernetes Cluster  ·  atlas-dev / atlas-staging / atlas-prod"]

    Ingress["Ingress\nnginx controller"]

    subgraph AppLayer["Application Services"]
      Portal["atlas-portal\nNode.js :8080"]
      API["orion-api\nFastAPI :8000"]
      Airflow["Apache Airflow\n:8081"]
      Notebook["notebook-lab\n:8888"]
    end

    subgraph ObsLayer["Observability  (design intent)"]
      Prom["Prometheus\nmetrics scrape"]
      Graf["Grafana\ndashboards"]
      Alert["Alertmanager"]
      Logs["Log Collector\nFluent Bit / Loki"]
    end

  end

  subgraph ExtSystems["External Systems  (private network)"]
    CDB[("Cloud DB\nRDS / Cloud SQL")]
    OPD[("On-Prem DB\nvia VPN")]
    OBS[("Object Storage\nS3 / GCS / Blob")]
    XAPI["External API\nHTTPS"]
  end

  User --> Ingress
  Ingress --> Portal
  Ingress --> API

  Portal -->|"API calls"| API
  Portal -. "card link" .-> Airflow
  Portal -. "card link" .-> Notebook
  Portal -. "card link" .-> Graf

  API -->|"private endpoint"| CDB
  API -->|"VPN tunnel"| OPD
  API -->|"IAM / workload identity"| OBS
  API -->|"HTTPS"| XAPI

  Airflow -->|"private endpoint"| CDB
  Airflow -->|"VPN tunnel"| OPD

  Prom -.->|"scrapes /metrics"| Portal
  Prom -.->|"scrapes /metrics"| API
  Prom -.->|"scrapes /metrics"| Airflow
  Prom --> Graf
  Prom --> Alert

  Logs -.->|"collects stdout/stderr"| Portal
  Logs -.->|"collects stdout/stderr"| API

  Alert -->|"alerts"| Notify["Slack / PagerDuty"]
```

**Legend:**
- Solid arrows `→` — direct API or data calls (runtime traffic)
- Dashed arrows `-.->` — portal UI card links (browser-side navigation) or monitoring collection
- Cluster subgraph — all services share the same Kubernetes namespace boundary per environment
- Observability layer — design intent; runtime components are outside assignment scope

---

## CI/CD Flow

The pipeline runs on every push and pull request to `dev`, `staging`, and `main`.
Kustomize validation and image builds run on all events. Image push and deployment run on branch pushes only.

```mermaid
flowchart TD
  Trigger["Pull request or push\ndev / staging / main"]

  subgraph Job1["Job 1: test-and-validate  (all events)"]
    Tests["Run portal and API tests\nnpm test  ·  pytest  ·  npm run lint"]
    Validate["Validate Kustomize overlays\ndev + staging + prod"]
    Tests --> Validate
  end

  subgraph Job2["Job 2: build-scan-push  (all events)"]
    Build["Build Docker images\natlas-portal  ·  orion-api"]
    Scan["Scan images with Trivy\nCRITICAL + HIGH"]
    Build --> Scan
  end

  PRCheck{"Push event?"}
  Push["Push images to GHCR\n:dev / :staging / :prod"]
  Branch{"Branch?"}
  Dev["Hand off to dev GitOps"]
  Staging["Hand off to staging GitOps"]
  Prod["Manual approval gate\nhand off to prod GitOps"]

  Trigger --> Job1
  Job1 --> Job2
  Job2 --> PRCheck
  PRCheck -->|"No — pull request\nstops here"| PRDone["PR validation complete"]
  PRCheck -->|"Yes"| Push
  Push --> Branch
  Branch -->|"dev"| Dev
  Branch -->|"staging"| Staging
  Branch -->|"main"| Prod
```

> Pull requests complete after the Scan step — images are built and scanned for early CVE feedback, but not pushed to the registry and not deployed.

For the full pipeline stage descriptions and branch-mapping table, see [cicd-pipeline.md](cicd-pipeline.md).

---

## Release Promotion

Releases move from dev to staging to prod by pull request. Each promotion triggers a full CI run before merge. Production requires a manual approval gate.

```mermaid
flowchart LR
  DevBranch["dev branch\natlas-dev namespace\nimage tag :dev"]
  StagePR["PR: dev → staging\nCI must pass\npeer review required"]
  StagingBranch["staging branch\natlas-staging namespace\nimage tag :staging"]
  ProdPR["PR: staging → main\nCI must pass\npeer review + approval gate"]
  MainBranch["main branch\natlas-prod namespace\nimage tag :prod"]

  DevBranch --> StagePR --> StagingBranch --> ProdPR --> MainBranch
```

For the full promotion process and environment differences, see [environments.md](environments.md).
