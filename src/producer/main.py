import time
import json
import logging
import requests
from kafka import KafkaProducer

# Konfiguration
# Die Adresse unseres neuen Strimzi-Clusters:
KAFKA_BROKER = "my-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"
TOPIC_NAME = "flight_data"
OPENSKY_URL = "https://opensky-network.org/api/states/all"

# Bereich (Schweiz/Süddeutschland), um Datenmenge zu begrenzen
BOUNDING_BOX = {"lamin": 45.8, "lomin": 5.9, "lamax": 47.8, "lomax": 10.5} 

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
            logger.info("✅ Erfolgreich mit Kafka verbunden!")
        except Exception as e:
            logger.error(f"❌ Kafka nicht erreichbar ({e}). Neuer Versuch in 5s...")
            time.sleep(5)
    return producer

def fetch_flight_data():
    """Holt Live-Daten von der OpenSky API."""
    try:
        response = requests.get(OPENSKY_URL, params=BOUNDING_BOX, timeout=10)
        if response.status_code == 200:
            data = response.json()
            return data.get("states", [])
        else:
            logger.warning(f"⚠️ OpenSky API Fehler: {response.status_code}")
            return []
    except Exception as e:
        logger.error(f"❌ Fehler beim Abrufen der Daten: {e}")
        return []

def main():
    producer = get_producer()
    logger.info("🚀 Starte Data Ingestion Loop...")
    
    while True:
        flights = fetch_flight_data()
        if flights:
            count = 0
            for flight in flights:
                record = {
                    "icao24": flight[0],
                    "callsign": flight[1].strip() if flight[1] else None,
                    "origin_country": flight[2],
                    "longitude": flight[5],
                    "latitude": flight[6],
                    "velocity": flight[9],
                    "timestamp": int(time.time())
                }
                # Nur senden, wenn Position da ist
                if record["longitude"] and record["latitude"]:
                    producer.send(TOPIC_NAME, value=record)
                    count += 1
            logger.info(f"📤 {count} Flüge an Kafka gesendet.")
        
        # OpenSky Free Tier Limit: Alle 10s
        time.sleep(10)



if __name__ == "__main__":
    main()