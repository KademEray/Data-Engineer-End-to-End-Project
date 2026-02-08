-- Datei: infrastructure/db/init_db.sql

-- Extension für UUIDs aktivieren (falls noch nicht aktiv)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================
-- 1. STAMMDATEN (Dimension Table)
-- =============================================
-- Speichert das Flugzeug EINMALig.
-- Egal wie oft es fliegt, die ID bleibt gleich.
-- =============================================
CREATE TABLE IF NOT EXISTS dim_aircrafts (
    aircraft_id SERIAL PRIMARY KEY,      -- Effiziente Integer-ID für Joins
    transponder_hex VARCHAR(24) UNIQUE,  -- Der "Fingerabdruck" (z.B. "3c666b")
    origin_country VARCHAR(100),         -- Herkunftsland
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_aircraft_hex ON dim_aircrafts(transponder_hex);


-- =============================================
-- 2. LIVE STATUS (Fact Table - Snapshot)
-- =============================================
-- Zeigt NUR Flugzeuge, die gerade aktiv sind.
-- Wird permanent per UPSERT aktualisiert.
-- =============================================
CREATE TABLE IF NOT EXISTS live_status (
    aircraft_ref_id INT PRIMARY KEY,     -- Link zu dim_aircrafts
    
    -- Flug-Details
    callsign VARCHAR(20),                -- Rufzeichen (z.B. "DLH123")
    
    -- Telemetrie (Aktuell)
    current_lat FLOAT,
    current_lon FLOAT,
    altitude_meters FLOAT,
    velocity_kmh FLOAT,
    heading_deg FLOAT,
    
    -- System
    last_contact_ts BIGINT,              -- Unix Timestamp für Timeouts
    
    CONSTRAINT fk_live_aircraft 
        FOREIGN KEY (aircraft_ref_id) 
        REFERENCES dim_aircrafts(aircraft_id)
        ON DELETE CASCADE                -- Wenn Flugzeug gelöscht wird, auch Status weg
);

-- Index für Timeout-Suche (Clean-Up Job)
CREATE INDEX IF NOT EXISTS idx_last_contact ON live_status(last_contact_ts);


-- =============================================
-- 3. FLIGHT SESSIONS (Fact Table - History)
-- =============================================
-- Speichert die Historie/Routen.
-- Ein Flugzeug kann tausende Sessions haben.
-- =============================================
CREATE TABLE IF NOT EXISTS flight_sessions (
    session_uuid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    aircraft_ref_id INT NOT NULL,
    callsign VARCHAR(20),
    
    start_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    end_time TIMESTAMP WITH TIME ZONE,   -- NULL = Flug noch aktiv
    
    -- Die Route als effizientes JSON-Array
    -- Format: [{"ts": 123, "lat": 48.1, "lon": 11.5}, ...]
    route_waypoints JSONB DEFAULT '[]'::jsonb,
    
    CONSTRAINT fk_session_aircraft 
        FOREIGN KEY (aircraft_ref_id) 
        REFERENCES dim_aircrafts(aircraft_id)
);

CREATE INDEX IF NOT EXISTS idx_session_aircraft ON flight_sessions(aircraft_ref_id);