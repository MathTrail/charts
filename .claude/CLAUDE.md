# MathTrail Helm Charts Repository - AI Assistant Guide

## Project Overview

**mathtrail-charts** is a Helm chart repository for the MathTrail project, hosted via GitHub Pages. It provides a library chart ([mathtrail-service-lib](../charts/mathtrail-service-lib)) that serves as a "constitution" for all MathTrail microservices, enforcing consistency, security, and best practices across the entire platform.

### Purpose
- **Single Source of Truth**: All MathTrail microservices inherit from this library chart
- **Enforced Standards**: Mandatory security policies, resource limits, and health probes
- **Reduced Boilerplate**: Microservice repos only need to provide values, not templates
- **Production-Ready Patterns**: Built-in Dapr integration, migrations, graceful shutdown, anti-affinity

## Architecture

### Repository Structure
```
mathtrail-charts/
├── charts/
│   ├── mathtrail-service-lib/    # Library chart (source code)
│   │   ├── Chart.yaml
│   │   ├── values.yaml            # Default values with comprehensive comments
│   │   ├── README.md
│   │   └── templates/
│   │       ├── _helpers.tpl       # Common functions, labels, validators
│   │       ├── _deployment.tpl    # Main app deployment with probes
│   │       ├── _service.tpl       # ClusterIP service
│   │       ├── _serviceaccount.tpl
│   │       ├── _rbac.tpl          # Role for migration init container
│   │       ├── _configmap.tpl     # Environment variables
│   │       ├── _job.tpl           # Pre-install migration job
│   │       └── _hpa.tpl           # Horizontal Pod Autoscaler
│   ├── *.tgz                      # Packaged charts (gitignored)
│   └── index.yaml                 # Helm repo index (auto-generated)
├── .github/workflows/
│   └── helm-repo.yml              # Publishes to GitHub Pages
├── justfile                       # Automation recipes
└── README.md
```

### Library Chart Contract

The `mathtrail-service-lib` enforces the following contract for all microservices:

| Layer | What it Enforces |
|-------|------------------|
| **Infrastructure** | Migration Job → Init Container → App Container lifecycle |
| **Reliability** | Mandatory CPU/Memory requests & limits + optional HPA |
| **Observability** | Startup, Liveness, Readiness probes with sensible defaults |
| **Dapr** | Sidecar annotations, app-id, app-port, protocol |
| **Security** | `runAsNonRoot`, `readOnlyRootFilesystem`, drop ALL capabilities |
| **Availability** | Default pod anti-affinity, graceful shutdown (preStop hook) |
| **RBAC** | ServiceAccount + Role for migration wait (kubectl) |

### Pod Lifecycle
```
┌─────────────────────────────────────┐
│ 1. Migration Job (Helm Hook)       │
│    pre-install/pre-upgrade          │
│    Runs DB migrations               │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│ 2. Init Container                   │
│    kubectl wait for migration       │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│ 3. App Container + Dapr Sidecar     │
│    Health probes → Ready → Traffic  │
└─────────────────────────────────────┘
```

## Common Tasks & Prompts

### 1. Adding a New Template to the Library

**Prompt:**
```
Add a new template to mathtrail-service-lib for [feature name, e.g., "Ingress", "NetworkPolicy", "PodDisruptionBudget"].
Follow the existing patterns:
- Create _[name].tpl in charts/mathtrail-service-lib/templates/
- Add configuration options to values.yaml with sensible defaults
- Include validation if fields are mandatory
- Document the template in the library README.md
- Ensure security best practices are followed
```

**Example:**
```
Add an Ingress template to mathtrail-service-lib that supports:
- Optional TLS with cert-manager annotations
- Path-based routing
- Defaults to nginx ingress class
- Includes the standard mathtrail labels
```

### 2. Updating Library Chart Version

**Prompt:**
```
Bump the mathtrail-service-lib version to [new version] in Chart.yaml and update the changelog/README.
Ensure semantic versioning:
- MAJOR: Breaking changes (e.g., renaming required values)
- MINOR: New features (e.g., new optional template)
- PATCH: Bug fixes, documentation updates
```

### 3. Adding New Infrastructure Charts

**Prompt:**
```
Add [chart name] to the Helm repository by:
1. Adding the helm repo to justfile in the update recipe
2. Adding helm pull command to download the chart
3. Running 'just update' to package and index
4. Testing the chart can be installed from the repo
```

**Example:**
```
Add the Jaeger Helm chart for distributed tracing to our repository.
Repository: https://jaegertracing.github.io/helm-charts
Chart: jaeger
```

### 4. Modifying Security Policies

**Prompt:**
```
Update the security context in _deployment.tpl to [requirement, e.g., "enforce a specific seccomp profile", "add support for fsGroup configuration"].
Ensure:
- Security is not weakened
- Changes are backward compatible (use defaults)
- Both podSecurityContext and securityContext are considered
- Document any breaking changes
```

### 5. Fixing Chart Validation Issues

**Prompt:**
```
A microservice is failing to deploy with error: [error message].
Debug the issue by:
1. Checking the validation logic in _helpers.tpl
2. Reviewing the microservice's values.yaml
3. Providing clear error messages via fail() function
4. Suggesting the correct configuration
```

### 6. Testing Chart Changes Locally

**Prompt:**
```
Create a minimal test values.yaml file for mathtrail-service-lib that I can use to:
1. Render the templates with 'helm template'
2. Validate the output with 'helm lint'
3. Test in a local Kubernetes cluster (kind/minikube)

Include realistic values for a simple HTTP service with DB migrations.
```

### 7. Updating Dapr Integration

**Prompt:**
```
Update the Dapr annotations in _helpers.tpl to support [new feature, e.g., "metrics port", "sidecar CPU limits", "placement host addresses"].
Reference the latest Dapr documentation for annotation names.
Ensure backward compatibility by making new settings optional.
```

### 8. Documenting Chart Usage

**Prompt:**
```
Create documentation for [specific scenario] showing:
1. The minimal Chart.yaml dependency declaration
2. The required values.yaml configuration
3. A complete templates/main.yaml example
4. Common gotchas and troubleshooting tips

Use the existing README.md style and markdown formatting.
```

## Development Workflow

### Making Changes to the Library Chart

1. **Edit Source Files**
   ```bash
   # Edit templates or values
   vim charts/mathtrail-service-lib/templates/_deployment.tpl
   vim charts/mathtrail-service-lib/values.yaml
   ```

2. **Update Version**
   ```bash
   # Edit Chart.yaml, bump version
   vim charts/mathtrail-service-lib/Chart.yaml
   ```

3. **Test Locally**
   ```bash
   # Render templates
   helm template test-release ./charts/mathtrail-service-lib -f test-values.yaml

   # Lint the chart
   helm lint ./charts/mathtrail-service-lib
   ```

4. **Package and Publish**
   ```bash
   # Run update to package and regenerate index
   just update

   # Commit and push to main
   git add .
   git commit -m "feat: [description]"
   git push

   # GitHub Actions will publish to Pages
   ```

### Testing in a Microservice

1. **Update Chart Dependency**
   ```yaml
   # in microservice Chart.yaml
   dependencies:
     - name: mathtrail-service-lib
       version: "0.1.0"  # or newer version
       repository: "file://../../mathtrail-charts/charts/mathtrail-service-lib"
   ```

2. **Build Dependencies**
   ```bash
   helm dependency update
   ```

3. **Install/Upgrade**
   ```bash
   helm upgrade --install my-service . --namespace dev
   ```

## Validation Rules (Enforced by Library)

The library uses `fail()` to enforce quality. Deployments will be rejected if:

- `image.repository` is empty
- `image.tag` is empty AND `Chart.AppVersion` is missing
- `resources.requests` is not defined
- `resources.limits` is not defined

These validations are in [_helpers.tpl](../charts/mathtrail-service-lib/templates/_helpers.tpl).

## Best Practices

### Versioning

- **Always bump the chart `version` in `Chart.yaml`** when making any change to a chart's templates, values, or configuration
- Use [Semantic Versioning](https://semver.org/): patch for fixes/tweaks, minor for new features, major for breaking changes
- This applies to all charts in the repository (library charts, application charts, etc.)

### When Working with Templates

1. **Never Hardcode Values**: Use `.Values.*` with sensible defaults
2. **Document Everything**: Add YAML comments to values.yaml explaining each option
3. **Validate Critical Fields**: Use `fail()` for truly mandatory configuration
4. **Security First**: Never weaken security defaults
5. **Test Rendering**: Always run `helm template` before committing

### When Adding New Features

1. **Make it Optional**: New features should default to disabled/null
2. **Backward Compatible**: Don't break existing microservices
3. **Follow Patterns**: Match the style of existing templates
4. **Update README**: Document new features immediately

### Resource Management

- **Always Specify Requests**: Required for pod scheduling
- **Always Specify Limits**: Prevents resource starvation
- **Be Conservative**: Start with low values, increase based on metrics
- **Migration Jobs**: Use lower resources than main app

## Troubleshooting

### Common Issues

**Issue: "FATAL: .Values.resources.requests must be defined"**
- **Cause**: Microservice values.yaml is missing resources section
- **Fix**: Add both requests and limits to values.yaml
- **Prompt**: "Show me the minimal resources configuration required for a microservice using mathtrail-service-lib"

**Issue: "Migration job never completes, pod stuck in Init"**
- **Cause**: Migration Job failed or RBAC permissions missing
- **Fix**: Check Job logs, ensure ServiceAccount has Role for kubectl wait
- **Prompt**: "Debug the migration Job and init container setup. Show me how to check logs and verify RBAC is correct."

**Issue: "Dapr sidecar not injecting"**
- **Cause**: dapr.enabled=false or Dapr not installed in cluster
- **Fix**: Set dapr.enabled=true and ensure Dapr is running
- **Prompt**: "Verify Dapr configuration in the deployment template and show me how to test sidecar injection"

**Issue: "Health probes failing immediately"**
- **Cause**: App doesn't implement probe endpoints or wrong paths
- **Fix**: Override probe paths in values.yaml or implement endpoints
- **Prompt**: "Show me how to customize health probe paths and what the application needs to implement"

## justfile Commands

The [justfile](../justfile) provides automation recipes:

```bash
# Update all charts (pull infrastructure + package library + regenerate index)
just update

# Override repo URL
just --set repo_url "https://my-org.github.io/charts" update
```

### What `just update` Does:
1. Updates Helm repos (bitnami, dapr, strimzi, grafana, open-telemetry)
2. Pulls infrastructure charts (.tgz):
   - postgresql, redis, strimzi-kafka-operator, dapr
   - k6-operator, k8s-monitoring, opentelemetry-collector, pyroscope
3. Packages mathtrail-service-lib from source
4. Generates index.yaml with proper URLs

## Integration Points

### GitHub Actions Workflow

The [.github/workflows/helm-repo.yml](../.github/workflows/helm-repo.yml) automatically:
- Triggers on push to `main` when charts/** changes
- Deploys entire repo to GitHub Pages
- Makes charts available at `https://MathTrail.github.io/charts`

**Prompt for CI/CD changes:**
```
Modify the GitHub Actions workflow to [requirement, e.g., "add chart validation", "publish release notes", "run security scanning"].
Ensure the deployment to GitHub Pages continues working.
```

### Consuming in Microservices

Microservices use the library via Helm dependencies:

```yaml
# Chart.yaml
dependencies:
  - name: mathtrail-service-lib
    version: "0.1.0"
    repository: "https://github.com/MathTrail/charts"

# templates/main.yaml
{{ include "mathtrail-service-lib.deployment" . }}
---
{{ include "mathtrail-service-lib.service" . }}
```

**Prompt for helping microservice developers:**
```
Show me how to create a new MathTrail microservice that uses mathtrail-service-lib.
Include:
- Minimal Chart.yaml with dependency
- Required values.yaml configuration for [type, e.g., "gRPC service with DB migrations"]
- Complete templates/main.yaml
```

## Planned Features

According to [charts/mathtrail-service-lib/README.md](../charts/mathtrail-service-lib/README.md), upcoming additions:

- Prometheus annotations (automatic metrics scraping)
- HashiCorp Vault / Dapr Secret Store integration
- PodDisruptionBudget template
- NetworkPolicy template
- Support for additional sidecar containers

**Prompt for implementing planned features:**
```
Implement [feature name] from the planned additions list.
Follow the existing template patterns and ensure:
- Optional by default (don't break existing deployments)
- Well documented in values.yaml
- Tested with helm template
- README updated with usage example
```

## Key Files Reference

| File | Purpose | When to Edit |
|------|---------|--------------|
| [charts/mathtrail-service-lib/Chart.yaml](../charts/mathtrail-service-lib/Chart.yaml) | Chart metadata, version | Bumping version |
| [charts/mathtrail-service-lib/values.yaml](../charts/mathtrail-service-lib/values.yaml) | Default configuration | Adding new options |
| [charts/mathtrail-service-lib/README.md](../charts/mathtrail-service-lib/README.md) | User documentation | New features, examples |
| [charts/mathtrail-service-lib/templates/_helpers.tpl](../charts/mathtrail-service-lib/templates/_helpers.tpl) | Functions, labels, validators | New helpers, validations |
| [charts/mathtrail-service-lib/templates/_deployment.tpl](../charts/mathtrail-service-lib/templates/_deployment.tpl) | Main app deployment | Probe, security, resource changes |
| [charts/mathtrail-service-lib/templates/_job.tpl](../charts/mathtrail-service-lib/templates/_job.tpl) | Migration Job | Migration behavior changes |
| [justfile](../justfile) | Build automation | Adding new charts to pull |
| [.github/workflows/helm-repo.yml](../.github/workflows/helm-repo.yml) | CI/CD pipeline | Publishing workflow changes |

## Security Considerations

The library enforces these security policies by default:

```yaml
# Pod-level
podSecurityContext:
  runAsNonRoot: true

# Container-level
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  capabilities:
    drop:
      - ALL
```

**Do NOT weaken these defaults without explicit security review.**

**Prompt for security changes:**
```
I need to [requirement, e.g., "allow writing to /tmp", "run as specific UID"].
Suggest the minimal security policy change while maintaining security best practices.
Explain the trade-offs and risks.
```

## Quick Reference: Common AI Prompts

### Analysis & Understanding
- "Explain how the migration Job and init container coordination works"
- "What happens if a microservice doesn't specify resource limits?"
- "Walk me through the pod lifecycle from helm install to traffic-ready"
- "Show me all the environment variables automatically injected into containers"

### Development
- "Add support for [feature] to the deployment template"
- "Create a new template for [resource type] following existing patterns"
- "Update the library to enforce [new requirement]"
- "Add validation to prevent [problematic configuration]"

### Debugging
- "A microservice deployment is failing with [error], help me debug"
- "The migration Job is stuck, how do I troubleshoot?"
- "Probes are failing, show me how to customize probe configuration"
- "Explain why Dapr sidecar is not injecting"

### Documentation
- "Document how to configure [feature] in the README"
- "Create a complete example for [use case]"
- "Explain the difference between [option A] and [option B]"

### Optimization
- "Suggest optimal resource requests/limits for [service type]"
- "How can I reduce startup time for [scenario]?"
- "What's the best anti-affinity configuration for [requirement]?"

## Version History

- **0.1.0** (Current): Initial architectural skeleton with core templates

---

**Last Updated:** 2026-02-08
**Maintained By:** MathTrail Team
**Repository:** https://github.com/MathTrail/charts
