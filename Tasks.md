0. Projekt-Struktur & Init
Ziel: Saubere Basis.

[ ] Ordnerstruktur anlegen:

Plaintext

.
├── .devcontainer/       # Container Config
├── .github/workflows/   # CI Pipelines
├── dags/                # Airflow DAGs
├── infrastructure/
│   ├── terraform/       # Base Infra (ArgoCD)
│   └── k8s/             # ArgoCD Manifeste (Apps)
├── src/
│   ├── producer/        # Python Code & Dockerfile
│   └── spark/           # PySpark Code & Dockerfile
└── setup.sh             # Cluster Start Script
[x] setup.sh erstellen: Skript zum Starten von K3d (wie oben besprochen).

[x] Git Init: Repository initialisieren und .gitignore (Python, Terraform, .venv) erstellen.

Phase 1: Base Infrastructure (Terraform)
Ziel: ArgoCD läuft im Cluster.

[x] Terraform Config (infrastructure/terraform/):

providers.tf: Konfiguration für Kubernetes, Helm und K3d Kontext.

main.tf:

Helm Release Resource für ArgoCD.

Kubernetes Namespace Resources: kafka, processing, airflow, database.

[x] Deploy: terraform init && terraform apply.

[x] Access Check: ArgoCD Admin-Passwort auslesen (kubectl get secret...) und UI Login (localhost:8081) testen.
-> kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

Getty Images
Entdecken
Phase 2: CI/CD (GitHub Actions)
Ziel: Docker Images werden automatisch gebaut.

[ ] Docker Registry: Account auf Docker Hub (oder GitHub Container Registry) prüfen.

[ ] Producer Image: src/producer/Dockerfile erstellen (Python Base, Requests Lib).

[ ] Spark Image: src/spark/Dockerfile erstellen (Spark Base, Postgres JDBC Driver, Kafka Client JARs).

[ ] GitHub Action (.github/workflows/build.yaml):

Trigger: Push auf main.

Jobs: Build & Push für Producer und Spark Image.

Secrets: DOCKER_USERNAME / PASSWORD in GitHub hinterlegen.

Phase 3: GitOps Configuration (ArgoCD)
Ziel: ArgoCD installiert die Data-Apps.

[ ] App of Apps Pattern: Erstelle infrastructure/k8s/root-app.yaml (Zeigt auf den Ordner apps).

[ ] App Definitionen (infrastructure/k8s/apps/):

kafka.yaml: Installiert Strimzi Operator & Kafka Cluster.

postgres.yaml: Installiert Bitnami PostgreSQL (mit statischem Passwort Secret).

airflow.yaml: Installiert Apache Airflow (Helm Chart).

superset.yaml: Installiert Apache Superset.

[ ] Sync: root-app.yaml manuell einmal anwenden (kubectl apply -f ...). ArgoCD übernimmt den Rest.

Phase 4: Application Code
Ziel: Die Logik implementieren.

[ ] Database Schema: ConfigMap oder Job erstellen, der die Tabelle flight_data in Postgres anlegt.

[ ] Producer Script (src/producer/main.py):

OpenSky API abfragen.

Daten filtern (Null-Werte).

JSON an Kafka Topic flights senden.

[ ] Spark Job (src/spark/processor.py):

readStream von Kafka.

Transformation (Schema Validation, Timestamp Parsing).

writeStream via JDBC nach Postgres.

Phase 5: Orchestration (Airflow)
Ziel: Alles verbinden.

[ ] Git-Sync: Airflow Helm Chart in Phase 3 so konfigurieren, dass es DAGs aus deinem Git-Repo (/dags) lädt.

[ ] DAG Erstellung (dags/pipeline.py):

KubernetesPodOperator: Startet den Producer-Container (als "Endless" Job oder Batch).

KubernetesPodOperator: Startet den Spark-Submit Befehl im Cluster.

Phase 6: Visualization
Ziel: Das Ergebnis sehen.

[ ] Superset Setup: Login in Superset UI.

[ ] DB Connection: Verbindung zu Postgres Service (postgresql.database.svc.cluster.local) herstellen.

[ ] Dataset: flight_data Tabelle importieren.

[ ] Chart: Weltkarte oder Balkendiagramm (Flüge pro Land) erstellen.