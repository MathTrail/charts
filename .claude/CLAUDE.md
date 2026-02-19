# MathTrail Helm Charts — AI Assistant Guide

## Identity & Context

This repo is the centralized Helm chart repository for all MathTrail services.
- Charts are served via GitHub Pages at `https://MathTrail.github.io/charts`
- Consumed by: all service repos (Helm dependency), ArgoCD (GitOps source)
- Tech Stack: Helm 3, GitHub Pages, GitHub Actions, `just`

---

## Repository Structure

```
mathtrail-charts/          # Chart sources (edit here)
├── mathtrail-service-lib/ # Library chart — constitution for all microservices
│   ├── Chart.yaml         # version: 0.1.3
│   ├── values.yaml        # Default values (comprehensive comments)
│   ├── README.md
│   └── templates/
│       ├── _helpers.tpl       # Labels, fullname, validators
│       ├── _defaults.tpl      # mergedValues helper — core abstraction
│       ├── _deployment.tpl    # Main app deployment with probes
│       ├── _service.tpl       # ClusterIP service
│       ├── _serviceaccount.tpl
│       ├── _rbac.tpl          # Role for migration init container
│       ├── _configmap.tpl     # Environment variables
│       ├── _job.tpl           # Pre-install migration job
│       ├── _hpa.tpl           # Horizontal Pod Autoscaler
│       └── _dashboard.tpl     # Grafana dashboard ConfigMap
├── github-runner/         # Self-hosted GitHub Actions runner (v0.2.8)
│   └── templates/         # deployment, secret, rbac, serviceaccount, buildkitd-config
└── k6-test-runner/        # Universal k6 load test runner (v0.1.1)

charts/                    # Published artifacts (auto-generated, do not edit)
├── *.tgz                  # Packaged charts
└── index.yaml             # Helm repo index

.github/workflows/
├── ci.yml                 # PR validation — runs just update + verify-charts-updated
└── release.yml            # Publishes to GitHub Pages on push to main

justfile                   # Automation recipes
```

---

## CRITICAL: Library Chart Value Access Pattern

Library chart `values.yaml` does **NOT** merge into the parent chart automatically.
Always use `dig` for nested value access — never `.Values.key1.key2`:

```yaml
# ❌ WRONG — will panic if key is absent
{{ .Values.serviceAccount.create }}

# ✅ CORRECT
{{ dig "serviceAccount" "create" true .Values }}
```

The `mergedValues` helper in `_defaults.tpl` is the core abstraction.
**Understand it before editing any template.**

---

## Library Chart Contract

| Layer | What it Enforces |
|-------|-----------------|
| **Infrastructure** | Migration Job → Init Container → App Container lifecycle |
| **Reliability** | Mandatory CPU/Memory requests & limits + optional HPA |
| **Observability** | Startup, Liveness, Readiness probes with sensible defaults |
| **Dapr** | Sidecar annotations, app-id, app-port, protocol |
| **Security** | `runAsNonRoot`, `readOnlyRootFilesystem`, drop ALL capabilities |
| **Availability** | Default pod anti-affinity, graceful shutdown (preStop hook) |
| **RBAC** | ServiceAccount + Role for migration wait (kubectl) |

### Pod Lifecycle
```
Migration Job (Helm Hook: pre-install/pre-upgrade)
       ↓
Init Container (kubectl wait for migration Job)
       ↓
App Container + Dapr Sidecar → Health probes → Ready → Traffic
```

### Validation Rules (enforced via `fail()`)

Deployments are rejected if:
- `image.repository` is empty
- `image.tag` is empty AND `Chart.AppVersion` is missing
- `resources.requests` is not defined
- `resources.limits` is not defined

---

## Development Workflow

### Editing the Library Chart

```bash
# 1. Edit source
vim mathtrail-charts/mathtrail-service-lib/templates/_deployment.tpl

# 2. Bump version in Chart.yaml (ALWAYS — semver)
#    patch: bug fix / docs, minor: new feature, major: breaking change

# 3. Lint
helm lint mathtrail-charts/mathtrail-service-lib/

# 4. Render templates
helm template test mathtrail-charts/mathtrail-service-lib/ -f test-values.yaml

# 5. Package and regenerate index
just update

# 6. Commit and push → GitHub Actions publishes to Pages
```

### justfile Commands

```bash
just update                  # Pull infra charts + package local charts + regenerate index.yaml
just verify-charts-updated   # Check that charts/ is in sync (used by CI)
```

### CI/CD

- **`ci.yml`**: runs on every PR — executes `just update` then `just verify-charts-updated` to ensure `charts/` is committed
- **`release.yml`**: runs on push to `main` — publishes to GitHub Pages

---

## Development Standards

- **Always bump `version` in `Chart.yaml`** on any template/values change (applies to all charts)
- **Never hardcode values** — use `.Values.*` with defaults
- **New features must be optional** — default to `false`/`null` to avoid breaking existing services
- **Security is non-negotiable** — never weaken `runAsNonRoot`, `readOnlyRootFilesystem`, `drop: [ALL]`
- **Test rendering** — run `helm template` before every commit

### Commit Convention (Conventional Commits)

```
feat(service-lib): add NetworkPolicy template
fix(service-lib): use dig for nested serviceAccount values
feat(github-runner): add buildkitd resource limits
chore(charts): bump chart versions after just update
```

---

## Consuming the Library in a Microservice

```yaml
# Chart.yaml
dependencies:
  - name: mathtrail-service-lib
    version: "0.1.3"
    repository: "https://MathTrail.github.io/charts"

# templates/main.yaml
{{ include "mathtrail-service-lib.deployment" . }}
---
{{ include "mathtrail-service-lib.service" . }}
```

---

## Security Defaults (Do NOT Weaken)

```yaml
podSecurityContext:
  runAsNonRoot: true

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  capabilities:
    drop: [ALL]
```

---

## Planned Features

- Prometheus annotations (automatic metrics scraping)
- HashiCorp Vault / Dapr Secret Store integration
- PodDisruptionBudget template
- NetworkPolicy template
- Support for additional sidecar containers

---

## Key Files Reference

| File | Purpose | When to Edit |
|------|---------|--------------|
| `mathtrail-charts/mathtrail-service-lib/Chart.yaml` | Version | Every change |
| `mathtrail-charts/mathtrail-service-lib/values.yaml` | Default config | New options |
| `mathtrail-charts/mathtrail-service-lib/templates/_defaults.tpl` | `mergedValues` helper | Core logic changes |
| `mathtrail-charts/mathtrail-service-lib/templates/_helpers.tpl` | Labels, validators | New helpers |
| `mathtrail-charts/mathtrail-service-lib/templates/_deployment.tpl` | App deployment | Probes, security, resources |
| `mathtrail-charts/mathtrail-service-lib/templates/_job.tpl` | Migration Job | Migration behavior |
| `mathtrail-charts/github-runner/` | Self-hosted CI runner | Runner config changes |
| `mathtrail-charts/k6-test-runner/` | Load test runner | k6 test config changes |
| `justfile` | Build automation | New charts to pull |
| `.github/workflows/ci.yml` | PR validation | CI checks |
| `.github/workflows/release.yml` | Publishing | Release pipeline |

---

**Last Updated:** 2026-02-19
**Maintained By:** MathTrail Team
**Repository:** https://github.com/MathTrail/charts
