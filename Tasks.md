# Projekt Aufgabenliste

## 1. Infrastruktur & Setup (✅ ERLEDIGT)
- [x] DevContainer Einrichtung.
- [x] K3d Cluster Setup Skript.
- [x] ArgoCD Installation & Ingress.
- [x] GitOps Repository Struktur.

## 2. Data Ingestion Layer (✅ ERLEDIGT)
- [x] **Message Broker (Strimzi Kafka):** Cluster & CRDs installiert.
- [x] **Datenbank (Postgres Vanilla):** Deployment & PVC installiert.
- [x] **Producer (Python):** Code, Dockerfile, CI-Pipeline (GitHub Action).
- [X] Linting: Prüfen, ob der Python-Code sauber geschrieben ist (pylint / flake8). // Testing: Automatisierte Tests (pytest), bevor das Image überhaupt gebaut wird.

## 3. DevOps & Automation (🚧 HIER SIND WIR)
- [ ] **Image Updater:**
    - [X] Updater im Cluster installieren.
    - [X] Annotations zur Producer-App hinzufügen.
- [ ] **Testlauf:** Code ändern -> Push -> Automatischer Deploy im Cluster beobachten.
---Aktuell klappt nicht wird später wieder versucht, zurzeit manuell mit:
kubectl rollout restart deployment opensky-producer -n kafka

## 4. Data Processing Layer (Verschoben)
- [ ] **Spark Setup:**
    - [ ] Dockerfile für Spark Consumer.
    - [ ] Deployment erstellen.
- [ ] **Stream Processing:** Kafka -> Spark -> Postgres.

- Apache Airflow

## 5. Visualization & Monitoring (Geplant)
- [ ] Streamlit Dashboard.
- [ ] Kafka UI.