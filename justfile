#!/usr/bin/env just --justfile

# The base URL where this Helm repo will be hosted (GitHub Pages)
# Override with: just --set repo_url "https://..." update
repo_url := "https://MathTrail.github.io/charts"

# Update all Helm charts and regenerate the repo index
update:
    #!/bin/bash
    set -e

    echo "📦 Updating Helm repositories..."
    helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
    helm repo add dapr https://dapr.github.io/helm-charts 2>/dev/null || true
    helm repo add strimzi https://strimzi.io/charts/ 2>/dev/null || true
    helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts 2>/dev/null || true
    helm repo add datawire https://app.getambassador.io 2>/dev/null || true
    helm repo add chaos-mesh https://charts.chaos-mesh.org 2>/dev/null || true
    helm repo add ory https://k8s.ory.sh/helm/charts 2>/dev/null || true
    helm repo add hashicorp https://helm.releases.hashicorp.com 2>/dev/null || true
    helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true

    helm repo update

    mkdir -p ./charts

    # Helper: remove old .tgz for a chart, then pull latest
    pull_chart() {
        local name="$1" repo="$2"
        rm -f ./charts/${name}-*.tgz
        helm pull "$repo" --destination ./charts
    }

    echo "📥 Pulling Infrastructure charts..."
    pull_chart postgresql bitnami/postgresql
    pull_chart redis bitnami/redis
    pull_chart strimzi-kafka-operator strimzi/strimzi-kafka-operator
    pull_chart dapr dapr/dapr

    echo "📥 Pulling Identity (Ory) charts..."
    pull_chart kratos ory/kratos
    pull_chart hydra ory/hydra
    pull_chart keto ory/keto
    pull_chart oathkeeper ory/oathkeeper

    echo "📥 Pulling Observability (LGTM + OTel) charts..."
    pull_chart k6-operator grafana/k6-operator
    pull_chart k8s-monitoring grafana/k8s-monitoring
    pull_chart opentelemetry-collector open-telemetry/opentelemetry-collector
    pull_chart pyroscope grafana/pyroscope

    echo "📥 Pulling Security charts..."
    pull_chart vault hashicorp/vault
    pull_chart external-secrets external-secrets/external-secrets

    echo "📥 Pulling Chaos Engineering..."
    pull_chart chaos-mesh chaos-mesh/chaos-mesh

    echo "📥 Pulling Development Tools..."
    rm -f ./charts/telepresence-*.tgz
    helm pull oci://ghcr.io/telepresenceio/telepresence-oss --destination ./charts

    echo "📦 Packaging local project charts..."
    rm -f ./charts/mathtrail-service-lib-*.tgz
    helm package ./mathtrail-charts/mathtrail-service-lib --destination ./charts

    rm -f ./charts/github-runner-*.tgz
    helm package ./mathtrail-charts/github-runner --destination ./charts

    rm -f ./charts/k6-test-runner-*.tgz
    helm package ./mathtrail-charts/k6-test-runner --destination ./charts

    echo "📦 Generating Helm repo index..."
    helm repo index ./charts --url {{ repo_url }}/charts
    
    echo "✅ All charts updated successfully!"
    echo ""
    echo "📊 Charts available:"
    ls -1 ./charts/*.tgz
    echo ""
    echo "📋 Index generated at ./charts/index.yaml"

# Verify that charts/ is up to date with changes in mathtrail-charts/
verify-charts-updated:
    #!/bin/bash
    set -e
    if [ -n "$(git status --porcelain charts/)" ]; then
        echo "❌ charts/ changed after running 'just update'."
        echo "   Run 'just update' locally and commit the changes."
        git status --porcelain charts/
        exit 1
    fi
    echo "✅ Charts are up to date"
