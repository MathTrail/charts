# MathTrail Helm Charts Repository

A Helm chart repository for the MathTrail project, served via GitHub Pages. Charts are stored as packaged `.tgz` archives with an auto-generated `index.yaml`.

## Quick Start with DevContainer

The easiest way to work with these charts is using the included DevContainer:

1. **Install Prerequisites:**
   - [Docker Desktop](https://www.docker.com/products/docker-desktop)
   - [VS Code](https://code.visualstudio.com/) with [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

2. **Open in DevContainer:**
   - Open this folder in VS Code
   - Click the blue "Dev Container" button in the bottom-left corner (or use `F1` > "Dev Containers: Reopen in Container")

3. **Download Charts:**
   ```bash
   just update
   ```

## Download/Update Charts

```bash
# Download/update all charts and regenerate the repo index
just update
```

## Deploy Charts

```bash
helm repo add mathtrail https://RyazanovAlexander.github.io/mathtrail-charts/charts
helm install postgres mathtrail/postgresql -n mathtrail -f values/postgresql-values.yaml
helm install redis mathtrail/redis -n mathtrail -f values/redis-values.yaml
helm install kafka mathtrail/kafka -n mathtrail -f values/kafka-values.yaml
helm install dapr mathtrail/dapr -n dapr-system --create-namespace
```
