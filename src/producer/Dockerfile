FROM python:3.10-slim

WORKDIR /app

# Abhängigkeiten installieren
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Code kopieren
COPY main.py .

# Logs sofort anzeigen (wichtig für Kubernetes)
ENV PYTHONUNBUFFERED=1

CMD ["python", "main.py"]