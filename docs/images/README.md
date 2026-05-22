# Screenshots Guide

This directory stores screenshots for the assignment submission.  
Screenshots are not committed to the repository by default — capture them after local verification and add them before final submission.

---

## Screenshots to Capture

Capture these 7 screenshots after running `docker compose up --build -d` and completing the [testing guide](../testing-guide.md).

---

### 1. Atlas Portal — `portal.png`

**URL:** http://localhost:8080  
**What to show:** The full portal page with all four service cards visible — API Service, Apache Airflow, Notebook Service, Monitoring/Grafana.

**Reference in docs:**
```markdown
![Atlas Portal](docs/images/portal.png)
```

---

### 2. Grafana — Service Availability Dashboard — `grafana-service-availability.png`

**URL:** http://localhost:3000 → Dashboards → Atlas Platform → Atlas Platform — Service Availability  
**What to show:** All four stat panels green (Prometheus, atlas-portal, orion-api, airflow). Firing Alerts showing "None". The time-series graph with all lines at 1.

**Reference in docs:**
```markdown
![Grafana service availability dashboard](docs/images/grafana-service-availability.png)
```

---

### 3. Prometheus Targets — `prometheus-targets.png`

**URL:** http://localhost:9090/targets  
**What to show:** All four scrape targets in State=UP — prometheus, atlas-portal, orion-api, airflow-health.

**Reference in docs:**
```markdown
![Prometheus scrape targets all UP](docs/images/prometheus-targets.png)
```

---

### 4. Prometheus Alerts — Firing — `prometheus-alerts.png`

**URL:** http://localhost:9090/alerts  
**When to capture:** After running `docker compose stop portal` and waiting ~70 seconds.  
**What to show:** `AtlasPortalDown` alert in **FIRING** state with labels `severity=critical`, `service=atlas-portal`.

**Reference in docs:**
```markdown
![Prometheus alert firing after stopping atlas-portal](docs/images/prometheus-alerts.png)
```

---

### 5. Alertmanager — Active Alert — `alertmanager-alert.png`

**URL:** http://localhost:9093  
**When to capture:** After the Prometheus alert transitions to FIRING.  
**What to show:** `AtlasPortalDown` listed as an active alert, routed to the `webhook` receiver.

**Reference in docs:**
```markdown
![Alertmanager showing AtlasPortalDown active alert](docs/images/alertmanager-alert.png)
```

---

### 6. Webhook.site — Notification Received — `webhook-notification.png`

**URL:** your personal Webhook.site URL  
**When to capture:** After the alert fires and Alertmanager sends the notification.  
**What to show:** The POST request in the Webhook.site inbox with the JSON body visible — showing `alertname`, `status: "firing"`, and `summary`.

> ⚠️ **Before capturing:** blur or remove your unique Webhook.site UUID from the screenshot if you do not want it public.

**Reference in docs:**
```markdown
![Webhook.site receiving alert notification](docs/images/webhook-notification.png)
```

---

### 7. GitHub Actions — Passing — `github-actions.png`

**URL:** https://github.com/sornsub/coraline-assignment-2-temp/actions  
**What to show:** The latest workflow run on the `main` branch showing all three jobs passing — `test-and-validate`, `build-scan-push`, `deployment-plan` — with green checkmarks.

**Reference in docs:**
```markdown
![GitHub Actions workflow passing](docs/images/github-actions.png)
```

---

## Adding Screenshots to README.md

Once captured, add the images to the README using standard Markdown:

```markdown
## Screenshots

### Portal
![Atlas Portal](docs/images/portal.png)

### Grafana — All Services UP
![Grafana service availability](docs/images/grafana-service-availability.png)

### Prometheus Targets
![Prometheus targets all UP](docs/images/prometheus-targets.png)

### Alert Test — AtlasPortalDown Firing
![Prometheus alert firing](docs/images/prometheus-alerts.png)

### Alertmanager — Active Alert
![Alertmanager active alert](docs/images/alertmanager-alert.png)

### Webhook.site — Notification
![Webhook notification received](docs/images/webhook-notification.png)

### GitHub Actions — Passing
![GitHub Actions passing](docs/images/github-actions.png)
```

---

## File Naming Reference

| File | Screenshot content |
|---|---|
| `portal.png` | Atlas Portal at localhost:8080 |
| `grafana-service-availability.png` | Grafana dashboard, all panels green |
| `prometheus-targets.png` | Prometheus targets page, all UP |
| `prometheus-alerts.png` | AtlasPortalDown in FIRING state |
| `alertmanager-alert.png` | Alertmanager active alert |
| `webhook-notification.png` | Webhook.site POST received |
| `github-actions.png` | GitHub Actions passing on main |
