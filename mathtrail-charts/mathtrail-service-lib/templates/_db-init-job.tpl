{{/*
=======================================================================
  mathtrail-service-lib :: _db-init-job.tpl
  Database initialisation Job — runs as a Helm pre-install/pre-upgrade hook
  (weight 0, before migration weight 5).
  Creates the service's PostgreSQL database(s), sets up the pgbouncer
  lookup_user SECURITY DEFINER function, and (optionally) grants default
  privileges required by the Vault Database Secrets Engine.

  Usage in a service chart:
    templates/db-init-job.yaml:
      {{ include "mathtrail-service-lib.dbInitJob" . }}

  Required values (.Values.db.databases — list):
    db:
      databases:
        - name: mentor            # database name to create
          vaultPrivileges: true   # ALTER DEFAULT PRIVILEGES for Vault dynamic users
      appUser: mathtrail          # optional, default: mathtrail

  Notes:
  - Connects to postgres as superuser; reads password from K8s Secret
    named after db.postgresHost (key: postgres-password), created by Bitnami chart.
  - Idempotent: safe to re-run on helm upgrade.
  - Databases are NOT dropped on helm uninstall (intentional — preserves data).
  - PostgreSQL 15+: GRANT CREATE ON SCHEMA public is issued per database
    (PG15 removed the default CREATE privilege from the public schema).
  - db.postgresHost: optional, default postgres-postgresql. Override when using
    a dedicated postgres instance (e.g. mentor-postgres-postgresql).
=======================================================================
*/}}

{{- define "mathtrail-service-lib.dbInitJob" -}}
{{- /* .Values is common.Values (not map[string]interface{}), so dig cannot be called on it directly.
       Convert via toJson|fromJson to get a plain map that dig accepts. */}}
{{- $v := .Values | toJson | fromJson -}}
{{- $databases := dig "db" "databases" (list) $v -}}
{{- $postgresHost := dig "db" "postgresHost" "postgres-postgresql" $v -}}
{{- if $databases -}}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}-db-init
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
    app.kubernetes.io/component: db-init
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "0"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  backoffLimit: 5
  template:
    metadata:
      labels:
        {{- include "mathtrail-service-lib.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: db-init
    spec:
      restartPolicy: OnFailure
      containers:
        - name: db-init
          image: {{ dig "db" "initImage" "postgres:16-alpine" $v }}
          env:
            - name: PGHOST
              value: {{ $postgresHost }}
            - name: PGUSER
              value: postgres
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ $postgresHost }}
                  key: postgres-password
            - name: APP_USER
              value: {{ dig "db" "appUser" "mathtrail" $v | quote }}
          command: ["/bin/bash", "-c"]
          args:
            - |
              set -euo pipefail

              until pg_isready -h "$PGHOST" -U "$PGUSER" -q; do
                echo "Waiting for postgres..." && sleep 2
              done

              # Ensure pgbouncer_auth role exists. Idempotent: safe if already created
              # by Bitnami initdb script. Created here to avoid race condition where
              # pg_isready passes during Bitnami's temporary startup before initdb scripts run.
              psql -d postgres -c "
                DO \$\$
                BEGIN
                  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'pgbouncer_auth') THEN
                    CREATE ROLE pgbouncer_auth WITH LOGIN PASSWORD 'pgbouncer_auth_pass';
                  END IF;
                END \$\$;
              "

              {{ range $databases }}
              echo "=== Initializing database: {{ .name }} ==="

              # Create database (idempotent)
              psql -d postgres -tAc \
                "SELECT 1 FROM pg_database WHERE datname='{{ .name }}'" \
                | grep -q 1 \
                || psql -d postgres -c "CREATE DATABASE \"{{ .name }}\";"

              # Grant app user access
              psql -d postgres -c \
                "GRANT ALL PRIVILEGES ON DATABASE \"{{ .name }}\" TO \"$APP_USER\";"

              # PostgreSQL 15+ removed the default CREATE privilege on the public schema.
              # GRANT ALL ON DATABASE is no longer sufficient — explicit schema grant required.
              psql -d "{{ .name }}" -c \
                "GRANT CREATE ON SCHEMA public TO \"$APP_USER\";"

              # pgbouncer auth: lookup_user SECURITY DEFINER function
              # ALTER FUNCTION OWNER ensures the function always runs as postgres,
              # even if a previous partial run left it owned by a non-superuser.
              psql -d "{{ .name }}" -c "
                SET SESSION AUTHORIZATION postgres;
                CREATE OR REPLACE FUNCTION public.lookup_user(p_user TEXT)
                  RETURNS TABLE(usename name, passwd text)
                  LANGUAGE sql SECURITY DEFINER AS
                  'SELECT usename, passwd FROM pg_shadow WHERE usename = p_user';
                ALTER FUNCTION public.lookup_user(TEXT) OWNER TO postgres;
                GRANT EXECUTE ON FUNCTION public.lookup_user(TEXT) TO pgbouncer_auth;
              "
              {{ if .vaultPrivileges }}
              # Vault Database Secrets Engine creates short-lived users.
              # Pre-grant default privileges so dynamic users get access to tables
              # created by future migrations (not just existing ones).
              psql -d "{{ .name }}" -c "
                ALTER DEFAULT PRIVILEGES IN SCHEMA public
                  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO PUBLIC;
                ALTER DEFAULT PRIVILEGES IN SCHEMA public
                  GRANT USAGE, SELECT ON SEQUENCES TO PUBLIC;
              "
              {{ end }}
              echo "Done: {{ .name }}"
              {{ end }}
              echo "All databases initialized."
{{- end }}
{{- end -}}
