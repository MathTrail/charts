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
    helm repo update bitnami dapr strimzi grafana
    
    mkdir -p ./charts
    
    echo "📥 Pulling PostgreSQL chart..."
    helm pull bitnami/postgresql --destination ./charts
    
    echo "📥 Pulling Redis chart..."
    helm pull bitnami/redis --destination ./charts
    
    echo "📥 Pulling Strimzi Kafka Operator chart..."
    helm pull strimzi/strimzi-kafka-operator --destination ./charts
    
    echo "📥 Pulling Dapr chart..."
    helm pull dapr/dapr --destination ./charts
    
    echo "📥 Pulling k6 Operator chart..."
    helm pull grafana/k6-operator --destination ./charts
    
    echo "📦 Generating Helm repo index..."
    helm repo index ./charts --url {{ repo_url }}/charts
    
    echo "✅ All charts updated successfully!"
    echo ""
    echo "📊 Charts available:"
    ls -1 ./charts/*.tgz
    echo ""
    echo "📋 Index generated at ./charts/index.yaml"
