# ✈️ Projekt Roadmap & Status

## 1. Infrastruktur & Setup (✅ ERLEDIGT)

* [x] **DevContainer:** Umgebung eingerichtet.
* [x] **Cluster:** K3d Setup Skript (`setup.sh`) erstellt.
* [x] **GitOps:** ArgoCD Installation, Ingress & Repository Struktur.

## 2. Data Ingestion Layer (✅ ERLEDIGT)

* [x] **Message Broker:** Strimzi Kafka Cluster & CRDs installiert.
* [x] **Datenbank:** Postgres Deployment & PVC installiert.
* [x] **Producer (Python):** Code zum Abruf der OpenSky API.
* [x] **Quality:** Linting (Pylint) & Testing (Pytest) in CI integriert.

## 3. DevOps & Automation (✅ ERLEDIGT)

* [x] **Image Updater:** ArgoCD Image Updater konfiguriert.
* [x] **CI/CD:** GitHub Actions Pipeline ("CI-Push" Pattern) läuft.
* [x] **Testlauf:** Automatisches Deployment nach Git-Push erfolgreich verifiziert.

## 🏗️ Phase 4: Storage Layer (PostgreSQL) (✅ ERLEDIGT)

*Status: Das Data Warehouse Fundament steht (Star Schema).*

* [x] **Task: Schema-Design `dim_aircrafts` & `live_status**`
* [x] Tabelle `dim_aircrafts` (Stammdaten, `transponder_hex`) erstellt.
* [x] Tabelle `live_status` (Echtzeit-View mit UPSERT-Logik) erstellt.
* [x] Indizes für Performance gesetzt.


* [x] **Task: Schema-Design `flight_sessions'**
* [x] Tabelle `flight_sessions` (Historie) erstellt.
* [x] `JSONB` Spalte für effiziente Routen-Speicherung implementiert.


* [x] **Task: Automatisierung**
* [x] `init_db.sql` Skript erstellt.
* [x] `setup.sh` erweitert: Automatische DB-Initialisierung mit Retry-Logik.


## 📨 Phase 5: Kafka Configuration (✅ ERLEDIGT)

*Das Bindeglied zwischen Producer und Consumer.*

* [x] **Task: Topic Setup**
* [x] Topic `flight_raw_data` angelegt.


* [x] **Task: Data Flow Check**
* [x] Producer sendet Daten (Verifiziert mit Consumer-Pod).



## 🧠 Phase 6: Processing Layer (Apache Spark)

*Das Herzstück: ETL, Transformation und Logik.*

* [ ] **Task: Spark Infrastruktur** 👈 **NÄCHSTER SCHRITT**
* [ ] Docker-Image für Spark erstellen (Custom Image mit Kafka/Postgres Treibern).
* [ ] K8s Manifeste für Spark-Submit/Deployment.


* [ ] **Task: Spark Streaming Job (PySpark Code)**
* [ ] `readStream` von Kafka implementieren.
* [ ] Schema (StructType) definieren.
* [ ] Transformationen: `m/s` in `km/h`, Bereinigung von Null-Werten.


* [ ] **Task: Die "Smart Write" Logik (`foreachBatch`)**
* [ ] **Logik A (Live View):** Lookup in `dim_aircrafts`, Upsert in `live_status`.
* [ ] **Logik B (History):** Prüfen, ob neuer Punkt zur Route in `flight_sessions` hinzugefügt werden muss (5-Minuten-Regel).

* [ ] **Task: Spark App Deployment**
* [ ] Integration in ArgoCD (`opensky-processor`).


* [ ] **Task: CI/CD Pipeline Erweiterung**
* [ ] Build & Push für das Spark-Image in GitHub Actions aufnehmen.


## ⏱️ Phase 7: Orchestration & Maintenance (Apache Airflow)

*Automatisierung und "Housekeeping".*

* [ ] **Task 4.1: "Flight End" Detector (Batch Job)**
* [ ] SQL-Logik: Identifiziere Flüge ohne Signal (> 20 min).
* [ ] Aktion: Setze `end_time` in Historie, lösche aus Live-View.


* [ ] **Task 4.2: Monitoring**
* [ ] Überwachung der Pipeline-Gesundheit.


## 8. Visualization & Monitoring (Geplant)

* [ ] Statistiken mit Power BI
* [ ] Streamlit Dashboard.
* [ ] Kafka UI.
