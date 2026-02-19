# mathtrail-charts

Centralized Helm chart repository for all MathTrail services, served via GitHub Pages.

```
helm repo add mathtrail https://MathTrail.github.io/charts
helm repo update
```

## What's Included

### MathTrail Charts (local sources)

| Chart | Version | Description |
|-------|---------|-------------|
| `mathtrail-service-lib` | 0.1.3 | Library chart — shared templates for all microservices |
| `github-runner` | 0.2.8 | Self-hosted GitHub Actions runner (BuildKit + Buildah) |
| `k6-test-runner` | 0.1.1 | Universal k6 load test runner |

### Infrastructure Charts (pulled from upstream)

| Category | Charts |
|----------|--------|
| **Data** | postgresql, redis, strimzi-kafka-operator |
| **Runtime** | dapr |
| **Identity (Ory)** | kratos, hydra, keto, oathkeeper |
| **Observability** | k6-operator, k8s-monitoring, opentelemetry-collector, pyroscope |
| **Security** | vault, external-secrets |
| **Chaos** | chaos-mesh |
| **Dev Tools** | telepresence-oss |

## Repository Structure

```
mathtrail-charts/          # Chart sources (edit here)
├── mathtrail-service-lib/ # Library chart
├── github-runner/         # CI runner chart
└── k6-test-runner/        # Load test runner chart

charts/                    # Published artifacts (auto-generated, do not edit)
├── *.tgz                  # Packaged charts
└── index.yaml             # Helm repo index

.github/workflows/
├── ci.yml                 # PR validation
└── release.yml            # Publishes to GitHub Pages on push to main

justfile                   # Automation recipes
```

## Development

```bash
# Pull upstream + package local charts + regenerate index.yaml
just update

# Verify charts/ is in sync (used by CI)
just verify-charts-updated
```

After editing a chart in `mathtrail-charts/`:
1. Bump `version` in the chart's `Chart.yaml` (semver)
2. Run `just update`
3. Commit everything (including `charts/`) and push

## Using mathtrail-service-lib

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

See [mathtrail-charts/mathtrail-service-lib/README.md](mathtrail-charts/mathtrail-service-lib/README.md) for full documentation.
