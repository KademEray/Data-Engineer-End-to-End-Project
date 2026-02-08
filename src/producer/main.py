import time
import json
import logging
import requests
import os
import sys
from kafka import KafkaProducer

# --- KONFIGURATION (via Environment Variables) ---
# Das macht den Code flexibel für Kubernetes!
KAFKA_BROKER = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "my-cluster-kafka-bootstrap.kafka.svc:9092")
TOPIC_NAME = os.getenv("KAFKA_TOPIC", "flight_raw_data")
OPENSKY_URL = "https://opensky-network.org/api/states/all"

# Credentials (Optional: Wenn gesetzt, nutzen wir sie)
OPENSKY_USER = os.getenv("OPENSKY_USERNAME")
OPENSKY_PASS = os.getenv("OPENSKY_PASSWORD")

# Wartezeit (Standard: 60s für anonyme Nutzer, 10s für eingeloggte)
# Wir lesen das aus der Env-Variable, die wir im YAML gesetzt haben
POLL_INTERVAL = int(os.getenv("POLL_INTERVAL", "180"))

# Bounding Box (Standard: DACH-Region / Süddeutschland)
# Wir können das jetzt auch über K8s steuern!
BOX_MIN_LAT = float(os.getenv("BOX_MIN_LAT", "45.8"))
BOX_MAX_LAT = float(os.getenv("BOX_MAX_LAT", "47.8"))
BOX_MIN_LON = float(os.getenv("BOX_MIN_LON", "5.9"))
BOX_MAX_LON = float(os.getenv("BOX_MAX_LON", "10.5"))

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def get_producer():
    """Erstellt eine Verbindung zu Kafka mit Retry-Logik."""
    producer = None
    while not producer:
        try:
            producer = KafkaProducer(
                bootstrap_servers=[KAFKA_BROKER],
                value_serializer=lambda x: json.dumps(x).encode('utf-8')
            )
            logger.info(f"✅ Erfolgreich mit Kafka ({KAFKA_BROKER}) verbunden!")
        except Exception as e:
            logger.error(f"❌ Kafka nicht erreichbar ({e}). Neuer Versuch in 5s...")
            time.sleep(5)
    return producer

def fetch_flight_data():
    """Holt Live-Daten von der OpenSky API (mit Auth Support)."""
    params = {
        "lamin": BOX_MIN_LAT,
        "lomin": BOX_MIN_LON,
        "lamax": BOX_MAX_LAT,
        "lomax": BOX_MAX_LON
    }
    
    auth = None
    if OPENSKY_USER and OPENSKY_PASS:
        auth = (OPENSKY_USER, OPENSKY_PASS)
        
    try:
        response = requests.get(OPENSKY_URL, params=params, auth=auth, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            return data.get("states", [])
        elif response.status_code == 429:
            logger.warning("⚠️ OpenSky Rate Limit (429)! Wir fragen zu schnell ab.")
            return []
        else:
            logger.warning(f"⚠️ OpenSky API Fehler: {response.status_code}")
            return []
    except Exception as e:
        logger.error(f"❌ Fehler beim Abrufen der Daten: {e}")
        return []

def main():
    producer = get_producer()
    logger.info(f"🚀 Starte Data Loop (Intervall: {POLL_INTERVAL}s)...")
    
    while True:
        flights = fetch_flight_data()
        
        if flights:
            count = 0
            for flight in flights:
                # Wir bauen das Dictionary exakt so, wie Spark (json_schema) es erwartet
                record = {
                    "icao24": flight[0],
                    "callsign": flight[1].strip() if flight[1] else None,
                    "origin_country": flight[2],
                    "timestamp": flight[3],       # time_position
                    "longitude": flight[5],
                    "latitude": flight[6],
                    "altitude": flight[7],        # geo_altitude (Hinzugefügt!)
                    "velocity": flight[9],
                    "true_track": flight[10]      # heading (Hinzugefügt!)
                }
                
                # Nur senden, wenn Position da ist
                if record["longitude"] and record["latitude"]:
                    producer.send(TOPIC_NAME, value=record)
                    count += 1
            
            logger.info(f"📤 {count} Datensätze an Topic '{TOPIC_NAME}' gesendet.")
        else:
            logger.info("Keine Flugdaten empfangen (oder API Fehler).")

        # Dynamisches Warten (gesteuert durch K8s Env Var)
        logger.info(f"💤 Warte {POLL_INTERVAL} Sekunden...")
        time.sleep(POLL_INTERVAL)

if __name__ == "__main__":
    main()