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
- [X] **Image Updater:**
    - [X] Updater im Cluster installieren.
    - [X] Annotations zur Producer-App hinzufügen.
- [X] **Testlauf:** Code ändern -> Push -> Automatischer Deploy im Cluster beobachten.

## 🏗️ Phase 4: Storage Layer (PostgreSQL)
*Das Ziel: Ein intelligentes Datenmodell, das Live-Zustand und Historie trennt.*

- [ ] **Task 1.1: Schema-Design `live_flights` (Der "State")**
    - [ ] Tabelle erstellen: `live_flights`.
    - [ ] **PK:** `icao24` (Muss unique sein).
    - [ ] **Spalten:** `callsign`, `lat`, `lon`, `altitude`, `velocity_kmh` (berechnet), `heading`, `last_contact` (Unix Timestamp).
    - [ ] **Indizes:** Index auf `last_contact` setzen (wichtig für Timeout-Abfragen später).

- [ ] **Task 1.2: Schema-Design `flight_histories` (Der "Log")**
    - [ ] Tabelle erstellen: `flight_histories`.
    - [ ] **PK:** `flight_uuid` (generiert beim ersten Kontakt).
    - [ ] **Spalten:** `icao24`, `start_time`, `end_time`, `origin_country`.
    - [ ] **Daten-Spalte:** `route_data` (Typ `JSONB` oder separate Tabelle für Wegpunkte), speichert Array aus `[lat, lon, time]`.
    - [ ] **Constraint:** Foreign Key zu `live_flights` (optional, je nach Lösch-Strategie).

---

## 📨 Phase 5: Ingestion Layer (Kafka & Producer)
*Status: ✅ Bereits implementiert. Hier zur Vollständigkeit.*

- [x] **Task 2.1: Kafka Topic Setup**
    - [x] Topic: `flight_raw_data`.
    - [ ] **Retention Policy:** Auf z.B. 2-6 Stunden setzen (Puffer für Spark-Wartung).
- [x] **Task 2.2: Python Producer**
    - [x] OpenSky API Abruf (DACH Region).
    - [x] JSON Serialisierung.
    - [x] Push zu Kafka.

---

## 🧠 Phase 6: Processing Layer (Apache Spark)
*Das Herzstück: ETL, Transformation und State-Management.*

- [ ] **Task 3.1: Spark Infrastruktur**
    - [ ] Docker-Image für Spark erstellen (Basis: Bitnami oder Apache).
    - [ ] **Dependencies:** Hinzufügen der JARs für `spark-sql-kafka` und `postgresql-jdbc`.
    - [ ] Spark-Master/Worker im K8s Cluster (oder Nutzung von `spark-submit` im Client Mode).

- [ ] **Task 3.2: Spark Streaming Job (Python/PySpark)**
    - [ ] `readStream` von Kafka initialisieren.
    - [ ] **Schema Definition:** JSON-Schema für die Rohdaten festlegen (StructType).
    - [ ] **Transformation:**
        - [ ] Filter: `null` Koordinaten verwerfen.
        - [ ] Berechnung: `velocity` * 3.6 = `km/h`.
        - [ ] Timestamp Conversion: Unix Int -> Timestamp Type.

- [ ] **Task 3.3: Die "Smart Write" Logik (`foreachBatch`)**
    - [ ] Implementierung der Funktion `process_batch(df, epoch_id)`:
    - [ ] **Logik A (Live View):**
        - [ ] JDBC Connection zu Postgres aufbauen.
        - [ ] `INSERT ... ON CONFLICT (icao24) DO UPDATE` (Upsert Pattern).
    - [ ] **Logik B (History Sampler - 5 Min Regel):**
        - [ ] Join/Lookup mit `live_flights` oder internem State.
        - [ ] Check: Ist `current_time - last_history_entry > 5 min`?
        - [ ] Wenn JA: Append an `flight_histories` (bzw. Update des JSON-Arrays).

---

## ⏱️ Phase 7: Orchestration & Maintenance (Apache Airflow)
*Automatisierung und "Housekeeping".*

- [ ] **Task 4.1: "Flight End" Detector (Der Aufräumer)**
    - [ ] **Problem:** Flugzeuge melden sich nicht ab, sie verschwinden einfach.
    - [ ] **DAG (Batch Job):** Läuft alle 5-10 Minuten.
    - [ ] **SQL-Logik:** `SELECT * FROM live_flights WHERE last_contact < (NOW() - INTERVAL '20 minutes')`.
    - [ ] **Aktion:**
        1. Setze `end_time` in `flight_histories`.
        2. Lösche Eintrag aus `live_flights`.

- [ ] **Task 4.2: Pipeline Monitoring**
    - [ ] Check: Schreibt Spark noch Daten? (Data Freshness Alert).
    - [ ] Check: Ist Kafka Topic Lag zu hoch?

---

## 🚀 Phase 8: Deployment & GitOps (CI/CD)
*Wie der Code in den Cluster kommt.*

- [ ] **Task 5.1: Database Migration Scripts**
    - [ ] K8s Job erstellen, der beim Start die SQL-Tabellen anlegt (via `kubectl apply`).

- [ ] **Task 5.2: Spark App Deployment**
    - [ ] Packaging des PySpark-Codes in Docker.
    - [ ] K8s Deployment Manifest für den Spark Consumer (`spark-submit`).
    - [ ] Integration in ArgoCD (Application: `opensky-processor`).

- [ ] **Task 5.3: CI/CD Pipeline Update**
    - [ ] GitHub Action erweitern: Build & Push für das Spark-Image.
    - [ ] Update der `kustomization.yaml` für den Processor.

## 9. Visualization & Monitoring (Geplant)
- [ ] Streamlit Dashboard.
- [ ] Kafka UI.