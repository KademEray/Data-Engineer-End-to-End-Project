# Offizielles Image von der Apache Foundation
FROM apache/spark:3.5.0

USER root

# 1. System-Updates
RUN apt-get update && \
    apt-get install -y curl && \
    rm -rf /var/lib/apt/lists/*

# 2. Treiber herunterladen (JARs)
# Wir legen sie direkt in den Classpath (/opt/spark/jars)

# A) PostgreSQL Treiber (hatten wir schon)
RUN curl -o /opt/spark/jars/postgresql-42.7.2.jar https://jdbc.postgresql.org/download/postgresql-42.7.2.jar

# B) Kafka Treiber & Abhängigkeiten (NEU! ⚡)
# Spark SQL Kafka Connector
RUN curl -o /opt/spark/jars/spark-sql-kafka-0-10_2.12-3.5.0.jar https://repo1.maven.org/maven2/org/apache/spark/spark-sql-kafka-0-10_2.12/3.5.0/spark-sql-kafka-0-10_2.12-3.5.0.jar

# Kafka Clients (Der Motor unter der Haube)
RUN curl -o /opt/spark/jars/kafka-clients-3.4.1.jar https://repo1.maven.org/maven2/org/apache/kafka/kafka-clients/3.4.1/kafka-clients-3.4.1.jar

# Token Provider (Wichtig für Spark 3.5+)
RUN curl -o /opt/spark/jars/spark-token-provider-kafka-0-10_2.12-3.5.0.jar https://repo1.maven.org/maven2/org/apache/spark/spark-token-provider-kafka-0-10_2.12/3.5.0/spark-token-provider-kafka-0-10_2.12-3.5.0.jar

# Commons Pool (Wird intern gebraucht)
RUN curl -o /opt/spark/jars/commons-pool2-2.11.1.jar https://repo1.maven.org/maven2/org/apache/commons/commons-pool2/2.11.1/commons-pool2-2.11.1.jar

# 3. Python Dependencies installieren
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# 4. Arbeitsverzeichnis
WORKDIR /opt/spark/work-dir

# 5. Code kopieren
COPY main.py .

# Zurück zum Standard-User
USER 185