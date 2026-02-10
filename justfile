#!/usr/bin/env just --justfile

# The base URL where this Helm repo will be hosted (GitHub Pages)
# Override with: just --set repo_url "https://..." update
repo_url := "https://RyazanovAlexander.github.io/mathtrail-charts"

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

    helm repo update

    mkdir -p ./charts

    echo "📥 Pulling Infrastructure charts..."
    helm pull bitnami/postgresql --destination ./charts
    helm pull bitnami/redis --destination ./charts
    helm pull strimzi/strimzi-kafka-operator --destination ./charts
    helm pull dapr/dapr --destination ./charts

    echo "📥 Pulling Observability (LGTM + OTel) charts..."
    helm pull grafana/k6-operator --destination ./charts
    helm pull grafana/k8s-monitoring --destination ./charts
    helm pull open-telemetry/opentelemetry-collector --destination ./charts
    helm pull grafana/pyroscope --destination ./charts

    echo "📥 Pulling Chaos Engineering..."
    helm pull chaos-mesh/chaos-mesh --destination ./charts

    echo "📥 Pulling Development Tools..."
    helm pull datawire/telepresence --destination ./charts

    echo "📦 Packaging mathtrail-service-lib library chart..."
    helm package ./charts/mathtrail-service-lib --destination ./charts

    echo "📦 Generating Helm repo index..."
    helm repo index ./charts --url {{ repo_url }}/charts
    
    echo "✅ All charts updated successfully!"
    echo ""
    echo "📊 Charts available:"
    ls -1 ./charts/*.tgz
    echo ""
    echo "📋 Index generated at ./charts/index.yaml"
