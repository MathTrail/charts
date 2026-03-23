{{/*
=======================================================================
  mathtrail-service-lib :: _risingwave-cdc-job.tpl
  RisingWave CDC Job — sets up a domain-owned Change Data Capture pipeline.

  Runs as a post-install/post-upgrade hook so that Kubernetes resources
  (e.g. Kratos PostgreSQL) are deployed before CDC wiring begins.

  Step 1 — initContainer: cdc-pg-setup
    Connects to the source PostgreSQL database and idempotently creates:
      • PUBLICATION covering the tables listed in pgSource.tables
      • Logical replication slot with pgoutput decoder
    Both are guarded by IF NOT EXISTS / EXCEPTION WHEN duplicate_object checks.

  Step 2 — initContainer: render-sql
    Runs envsubst with an explicit variable list to render ${ENV_VAR}
    placeholders in the SQL. The explicit list prevents envsubst from
    corrupting PostgreSQL $$ dollar-quote syntax used in future SQL blocks.

  Step 3 — main container: risingwave-sql
    Waits for the RisingWave frontend to be ready, then executes the
    rendered SQL (CREATE SOURCE / TABLE / MATERIALIZED VIEW / SINK).

  Idempotency:
    • CREATE SOURCE/TABLE/SINK IF NOT EXISTS — safe on every upgrade.
    • CREATE MATERIALIZED VIEW IF NOT EXISTS — safe, but NOT replaceable.
      If the MV definition changes, a manual DROP MATERIALIZED VIEW ... CASCADE
      is required first (which also drops dependent SINKs). Document this
      constraint in the service's values.yaml.

  Credentials:
    The library template references K8s Secrets by name only — it does not
    create them. Each service is responsible for provisioning:
      • pgSource.credentialsSecret  — Secret with 'username' and 'password' keys
      • automq.credentialsSecret    — Secret with 'username' and 'password' keys
    Typically created via VSO VaultStaticSecret CRs in the service chart.
    If the Secret does not exist when the Job starts, the Pod will fail with
    CreateContainerConfigError and retry (backoffLimit handles this).
=======================================================================
*/}}

{{- define "mathtrail-service-lib.risingwaveCdcJob" -}}
{{- $v := include "mathtrail-service-lib.mergedValues" . | fromYaml }}
{{- if $v.risingwaveCdc.enabled }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}-rw-cdc-sql
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
    app.kubernetes.io/component: risingwave-cdc
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-weight": {{ $v.risingwaveCdc.hookWeight | quote }}
    "helm.sh/hook-delete-policy": before-hook-creation
data:
  setup.sql: |
{{ $v.risingwaveCdc.sql | indent 4 -}}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "mathtrail-service-lib.fullname" . }}-rw-cdc-setup
  labels:
    {{- include "mathtrail-service-lib.labels" . | nindent 4 }}
    app.kubernetes.io/component: risingwave-cdc
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-weight": {{ $v.risingwaveCdc.hookWeight | quote }}
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  backoffLimit: {{ $v.risingwaveCdc.backoffLimit }}
  ttlSecondsAfterFinished: {{ $v.risingwaveCdc.ttlSecondsAfterFinished }}
  template:
    metadata:
      labels:
        {{- include "mathtrail-service-lib.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: risingwave-cdc
    spec:
      restartPolicy: OnFailure
      initContainers:
        # Step 1: Create PostgreSQL publication and replication slot (idempotent).
        - name: cdc-pg-setup
          image: bitnami/postgresql:16
          env:
            - name: PGHOST
              value: {{ $v.risingwaveCdc.pgSource.host | quote }}
            - name: PGPORT
              value: {{ $v.risingwaveCdc.pgSource.port | quote }}
            - name: PGDATABASE
              value: {{ $v.risingwaveCdc.pgSource.database | quote }}
            - name: PGUSER
              valueFrom:
                secretKeyRef:
                  name: {{ $v.risingwaveCdc.pgSource.credentialsSecret | quote }}
                  key: username
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ $v.risingwaveCdc.pgSource.credentialsSecret | quote }}
                  key: password
          command:
            - bash
            - -c
            - |
              set -e

              echo "Creating PostgreSQL publication for RisingWave CDC..."
              psql -c "
                DO \$\$
                BEGIN
                  CREATE PUBLICATION {{ $v.risingwaveCdc.pgSource.publicationName }}
                    FOR TABLE {{ join ", " $v.risingwaveCdc.pgSource.tables }};
                EXCEPTION
                  WHEN duplicate_object THEN
                    RAISE NOTICE 'Publication already exists, skipping.';
                END
                \$\$;
              "

              echo "Creating replication slot..."
              psql -c "
                SELECT CASE
                  WHEN NOT EXISTS (
                    SELECT 1 FROM pg_replication_slots
                    WHERE slot_name = '{{ $v.risingwaveCdc.pgSource.slotName }}'
                  )
                  THEN pg_create_logical_replication_slot(
                    '{{ $v.risingwaveCdc.pgSource.slotName }}', 'pgoutput'
                  )
                  ELSE NULL
                END;
              "

              echo "CDC PG setup complete."
              echo "  Publication : {{ $v.risingwaveCdc.pgSource.publicationName }}"
              echo "  Slot        : {{ $v.risingwaveCdc.pgSource.slotName }}"

        # Step 2: Render ${ENV_VAR} placeholders in the SQL using envsubst.
        # Explicit variable list prevents envsubst from substituting $$ used in
        # PostgreSQL dollar-quote blocks (if any future SQL uses them).
        - name: render-sql
          image: alpine:3.20
          env:
            - name: PG_HOST
              value: {{ $v.risingwaveCdc.pgSource.host | quote }}
            - name: PG_PORT
              value: {{ $v.risingwaveCdc.pgSource.port | quote }}
            - name: PG_DATABASE
              value: {{ $v.risingwaveCdc.pgSource.database | quote }}
            - name: PG_USER
              valueFrom:
                secretKeyRef:
                  name: {{ $v.risingwaveCdc.pgSource.credentialsSecret | quote }}
                  key: username
            - name: PG_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ $v.risingwaveCdc.pgSource.credentialsSecret | quote }}
                  key: password
            - name: AUTOMQ_BOOTSTRAP_SERVER
              value: {{ $v.risingwaveCdc.automq.bootstrapServer | quote }}
            - name: AUTOMQ_USERNAME
              valueFrom:
                secretKeyRef:
                  name: {{ $v.risingwaveCdc.automq.credentialsSecret | quote }}
                  key: username
            - name: AUTOMQ_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ $v.risingwaveCdc.automq.credentialsSecret | quote }}
                  key: password
            - name: APICURIO_URL
              value: {{ $v.risingwaveCdc.apicurioUrl | quote }}
          command:
            - sh
            - -c
            - |
              apk add --no-cache gettext >/dev/null 2>&1
              envsubst '$PG_HOST $PG_PORT $PG_DATABASE $PG_USER $PG_PASSWORD $AUTOMQ_BOOTSTRAP_SERVER $AUTOMQ_USERNAME $AUTOMQ_PASSWORD $APICURIO_URL' \
                < /sql-template/setup.sql > /sql-rendered/setup.sql
              echo "SQL rendered successfully."
          volumeMounts:
            - name: sql-template
              mountPath: /sql-template
            - name: sql-rendered
              mountPath: /sql-rendered

      containers:
        # Step 3: Wait for RisingWave and execute the rendered SQL.
        - name: risingwave-sql
          # bitnami/postgresql provides psql client; RisingWave speaks the Postgres wire protocol.
          image: bitnami/postgresql:16
          env:
            - name: RW_HOST
              value: {{ $v.risingwaveCdc.risingwave.host | quote }}
            - name: RW_PORT
              value: {{ $v.risingwaveCdc.risingwave.port | quote }}
            - name: RW_USER
              value: {{ $v.risingwaveCdc.risingwave.user | quote }}
            - name: RW_DATABASE
              value: {{ $v.risingwaveCdc.risingwave.database | quote }}
            - name: PGPASSWORD
              value: ""  # RisingWave has no password in dev mode
          command:
            - bash
            - -c
            - |
              set -e
              echo "Waiting for RisingWave frontend to be ready..."
              until psql -h "$RW_HOST" -p "$RW_PORT" -U "$RW_USER" -d "$RW_DATABASE" \
                -c "SELECT 1" > /dev/null 2>&1; do
                echo "  RisingWave not ready, retrying in 5s..."
                sleep 5
              done

              echo "Executing RisingWave CDC SQL setup..."
              psql -h "$RW_HOST" -p "$RW_PORT" -U "$RW_USER" -d "$RW_DATABASE" \
                -f /sql-rendered/setup.sql

              echo "RisingWave CDC setup complete."
          resources:
            {{- toYaml $v.risingwaveCdc.resources | nindent 12 }}
          volumeMounts:
            - name: sql-rendered
              mountPath: /sql-rendered

      volumes:
        - name: sql-template
          configMap:
            name: {{ include "mathtrail-service-lib.fullname" . }}-rw-cdc-sql
        - name: sql-rendered
          emptyDir: {}
{{- end }}
{{- end -}}
