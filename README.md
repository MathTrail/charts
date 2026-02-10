# MathTrail Helm Charts Repository

A Helm chart repository for the MathTrail project, served via GitHub Pages. Charts are stored as packaged `.tgz` archives with an auto-generated `index.yaml`.

## Charts

### mathtrail-service-lib (Library Chart)

Library Helm Chart for MathTrail microservices. Provides reusable templates with Dapr integration, mandatory probes, resource limits, and a security contract. See [charts/mathtrail-service-lib/README.md](charts/mathtrail-service-lib/README.md) for details.

## Download/Update Charts

```bash
# Download/update all charts and regenerate the repo index
just update
```
