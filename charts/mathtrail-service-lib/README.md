# mathtrail-service-lib

Library Helm Chart for MathTrail microservices.

> **Important:** This is an architectural skeleton, not a final production-ready chart. Additional layers (Prometheus, Vault integration, etc.) will be added as the project evolves.

## Purpose

`mathtrail-service-lib` is a "constitution" for MathTrail microservices. Instead of re-describing Deployments, Dapr annotations, migrations, and probes in every repository, we package everything into a single library chart.

The library **enforces a contract** that every microservice must follow:

| Layer | What it provides |
|---|---|
| **Infrastructure** | Migration Job → Init Container → App Container |
| **Reliability** | Requests/Limits (mandatory) + HPA |
| **Observability** | Startup/Liveness/Readiness probes with default paths |
| **Dapr** | Sidecar with correct ports and annotations |
| **Security** | `runAsNonRoot`, `readOnlyRootFilesystem`, `drop ALL capabilities` |
| **Availability** | Default Anti-Affinity, Graceful Shutdown (preStop hook) |
| **RBAC** | Role + RoleBinding for init-container (migration wait) |

## Architecture

The library implements a strict pod lifecycle:

```
Migration Job (Helm Hook: pre-install/pre-upgrade)
        ↓
Init Container (kubectl wait --for=condition=complete)
        ↓
App Container (main logic + Dapr Sidecar)
```

## Template Structure

```
templates/
  _helpers.tpl        # Names, labels, Dapr annotations, validation
  _job.tpl            # Migration Job (Helm Hook)
  _deployment.tpl     # Deployment + initContainers + probes + resources
  _service.tpl        # ClusterIP Service
  _serviceaccount.tpl # ServiceAccount
  _rbac.tpl           # Role + RoleBinding for migration wait
  _configmap.tpl      # ConfigMap for environment variables
  _hpa.tpl            # HorizontalPodAutoscaler
```

## Validation via `fail()`

The library uses Helm's `fail` function to enforce quality. Helm **will refuse to deploy** if:

- `image.repository` is not specified
- `image.tag` is not set and `appVersion` is missing
- `resources.requests` or `resources.limits` are not defined

## Usage in a Microservice

### 1. Microservice Chart.yaml

```yaml
apiVersion: v2
name: my-service
type: application
version: 0.1.0
appVersion: "1.0.0"

dependencies:
  - name: mathtrail-service-lib
    version: "0.1.0"
    repository: "https://<org>.github.io/mathtrail-charts"
```

### 2. templates/all.yaml

```yaml
{{ include "mathtrail-service-lib.serviceAccount" . }}
---
{{ include "mathtrail-service-lib.rbac" . }}
---
{{ include "mathtrail-service-lib.configMap" . }}
---
{{ include "mathtrail-service-lib.migrationJob" . }}
---
{{ include "mathtrail-service-lib.deployment" . }}
---
{{ include "mathtrail-service-lib.service" . }}
---
{{ include "mathtrail-service-lib.hpa" . }}
```

### 3. values.yaml (minimal)

```yaml
image:
  repository: "my-registry/my-service"
  tag: "1.0.0"

service:
  port: 8080

dapr:
  enabled: true
  appId: "my-service"

resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

## Available Templates

| Template | Description |
|---|---|
| `mathtrail-service-lib.deployment` | Deployment with Dapr, probes, resources, security, graceful shutdown |
| `mathtrail-service-lib.service` | ClusterIP Service |
| `mathtrail-service-lib.serviceAccount` | ServiceAccount |
| `mathtrail-service-lib.rbac` | Role + RoleBinding for init-container |
| `mathtrail-service-lib.migrationJob` | Pre-install/pre-upgrade Job for DB migrations |
| `mathtrail-service-lib.configMap` | ConfigMap from `configMap.data` |
| `mathtrail-service-lib.hpa` | HorizontalPodAutoscaler |

## Planned Additions

- Prometheus annotations (automatic metrics scraping)
- HashiCorp Vault / Dapr Secret Store integration
- PodDisruptionBudget
- NetworkPolicy
- Support for sidecar containers (beyond Dapr)
