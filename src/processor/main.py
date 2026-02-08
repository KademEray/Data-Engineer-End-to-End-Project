import logging
import sys
import os
import psycopg2

from pyspark.sql import SparkSession
from pyspark.sql.functions import from_json, col
from pyspark.sql.types import StructType, StructField, StringType, DoubleType, LongType

# --- LOGGING SETUP ---
logging.basicConfig(stream=sys.stdout, level=logging.INFO)
logger = logging.getLogger("OpenSkyProcessor")

# --- CONFIGURATION (via Environment Variables) ---
KAFKA_BOOTSTRAP_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "my-cluster-kafka-bootstrap.kafka.svc:9092")
KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "flight_raw_data")

DB_HOST = os.getenv("DB_HOST", "postgres-service.database.svc.cluster.local")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "flight_data")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD")

if not DB_PASSWORD:
    logger.error("❌ CRITICAL: DB_PASSWORD is not set!")
    sys.exit(1)

# --- SCHEMA DEFINITION ---
# Muss exakt zum Producer JSON passen
json_schema = StructType([
    StructField("icao24", StringType(), True),
    StructField("callsign", StringType(), True),
    StructField("origin_country", StringType(), True),
    StructField("longitude", DoubleType(), True),
    StructField("latitude", DoubleType(), True),
    StructField("altitude", DoubleType(), True),
    StructField("velocity", DoubleType(), True), # m/s
    StructField("true_track", DoubleType(), True),
    StructField("timestamp", LongType(), True)
])

def write_batch_to_postgres(batch_df, batch_id):
    """
    Dieser Code läuft auf dem Spark Worker für jeden Mini-Batch.
    """
    data = batch_df.collect()
    
    if not data:
        return

    logger.info(f"⚡ Batch {batch_id}: Verarbeite {len(data)} Flugzeuge...")

    conn = None
    try:
        # Verbindung zur DB aufbauen
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        conn.autocommit = False # Transaktionen nutzen
        cur = conn.cursor()

        processed_count = 0

        for row in data:
            # 1. Logic A: Stammdaten (dim_aircrafts)
            # Versuche Flugzeug anzulegen. Wenn es existiert -> egal (DO NOTHING)
            cur.execute("""
                INSERT INTO dim_aircrafts (transponder_hex, origin_country)
                VALUES (%s, %s)
                ON CONFLICT (transponder_hex) DO NOTHING;
            """, (row.icao24, row.origin_country))

            # 2. Logic A: ID holen
            # Wir brauchen die interne ID für die Verknüpfung
            cur.execute("SELECT aircraft_id FROM dim_aircrafts WHERE transponder_hex = %s", (row.icao24,))
            result = cur.fetchone()
            
            if result:
                aircraft_id = result[0]

                # 3. Logic A: Live Status Update (live_status)
                # Das ist das Herzstück: UPSERT. 
                # Wenn da -> Update Koordinaten. Wenn nicht da -> Insert.
                cur.execute("""
                    INSERT INTO live_status 
                    (aircraft_ref_id, callsign, current_lat, current_lon, altitude_meters, velocity_kmh, heading_deg, last_contact_ts)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (aircraft_ref_id) 
                    DO UPDATE SET
                        callsign = EXCLUDED.callsign,
                        current_lat = EXCLUDED.current_lat,
                        current_lon = EXCLUDED.current_lon,
                        altitude_meters = EXCLUDED.altitude_meters,
                        velocity_kmh = EXCLUDED.velocity_kmh,
                        heading_deg = EXCLUDED.heading_deg,
                        last_contact_ts = EXCLUDED.last_contact_ts;
                """, (
                    aircraft_id, 
                    row.callsign.strip() if row.callsign else None,
                    row.latitude, 
                    row.longitude, 
                    row.altitude, 
                    row.velocity_kmh, 
                    row.true_track, 
                    row.timestamp
                ))
                processed_count += 1
            
        conn.commit()
        logger.info(f"✅ Batch {batch_id}: {processed_count} Flugzeuge erfolgreich in DB gespeichert.")

    except Exception as e:
        logger.error(f"❌ Fehler im Batch {batch_id}: {e}")
        if conn:
            conn.rollback()
    finally:
        if conn:
            conn.close()

def main():
    logger.info("🚀 --- OpenSky Spark Processor Starting ---")
    logger.info(f"📡 Connect to Kafka: {KAFKA_BOOTSTRAP_SERVERS}")
    logger.info(f"🗄️ Connect to DB: {DB_HOST} (DB: {DB_NAME})")

    spark = SparkSession.builder \
        .appName("OpenSkyProcessor") \
        .getOrCreate()

    # Log Level reduzieren, damit wir unsere eigenen Logs sehen
    spark.sparkContext.setLogLevel("WARN")

    # 1. READ STREAM (Kafka)
    raw_df = spark.readStream \
        .format("kafka") \
        .option("kafka.bootstrap.servers", KAFKA_BOOTSTRAP_SERVERS) \
        .option("subscribe", KAFKA_TOPIC) \
        .option("startingOffsets", "latest") \
        .load()

    # 2. TRANSFORM
    # JSON String parsen -> Spalten
    parsed_df = raw_df.select(from_json(col("value").cast("string"), json_schema).alias("data")).select("data.*")

    # Filter: Nur gültige Koordinaten
    # Berechnen: m/s -> km/h
    final_df = parsed_df \
        .filter(col("latitude").isNotNull() & col("longitude").isNotNull()) \
        .withColumn("velocity_kmh", col("velocity") * 3.6)

    # 3. WRITE STREAM (ForeachBatch -> Postgres)
    query = final_df.writeStream \
        .outputMode("update") \
        .foreachBatch(write_batch_to_postgres) \
        .start()

    query.awaitTermination()


if __name__ == "__main__":
    main()