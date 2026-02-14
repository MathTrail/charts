# mathtrail-charts
Centralized Helm chart repository — stores packaged charts for all MathTrail services, served via GitHub Pages.

## Mission & Responsibilities
- Host packaged `.tgz` charts for all services
- Maintain `index.yaml` for Helm repo discovery
- Provide `mathtrail-service-lib` library chart (shared templates)
- Serve as source for ArgoCD deployments

## Structure
```
charts/
├── index.yaml                      # Helm repo index (auto-generated)
├── mathtrail-service-lib/          # Library chart (reusable templates)
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── _defaults.tpl           # mergedValues helper
│       ├── _deployment.tpl         # Deployment with Dapr, probes, security
│       ├── _service.tpl            # Service template
│       ├── _serviceaccount.tpl     # ServiceAccount + RBAC
│       ├── _helpers.tpl            # Name/label helpers
│       └── _hpa.tpl               # HorizontalPodAutoscaler
├── mathtrail-profile-0.1.0.tgz    # Packaged service charts
└── ...
```

## Publishing Flow
Service repo → `just release-chart` → packages chart → pushes to this repo → GitHub Pages serves index.yaml → ArgoCD syncs

## Development
- `just update` — Download/reindex all charts
