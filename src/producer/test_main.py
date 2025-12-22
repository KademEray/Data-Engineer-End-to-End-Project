import pytest
from unittest.mock import MagicMock, patch
from main import fetch_flight_data, get_producer

# 1. Test: Datenabruf von OpenSky (Erfolgreich)
@patch('main.requests.get')
def test_fetch_flight_data_success(mock_get):
    # Wir simulieren eine gefakte Antwort der API
    mock_response = MagicMock()
    mock_response.status_code = 200
    # So sieht eine OpenSky Antwort aus (vereinfacht):
    mock_response.json.return_value = {
        "states": [
            ["icao1", "Lufthansa 123", "Germany", 0, 0, 10.5, 50.1, 0, False, 200.0, 0, 0, 0, 0, 0, False, 0]
        ]
    }
    mock_get.return_value = mock_response

    # Wir rufen die echte Funktion auf
    result = fetch_flight_data()

    # Wir prüfen: Hat sie die Daten korrekt zurückgegeben?
    assert len(result) == 1
    assert result[0][1] == "Lufthansa 123"

# 2. Test: Datenabruf Fehler (404/500)
@patch('main.requests.get')
def test_fetch_flight_data_failure(mock_get):
    mock_response = MagicMock()
    mock_response.status_code = 500 # Server Error simulieren
    mock_get.return_value = mock_response

    result = fetch_flight_data()

    # Bei Fehler soll eine leere Liste zurückkommen (siehe main.py Logik)
    assert result == []

# 3. Test: Kafka Producer Verbindung (Mock)
@patch('main.KafkaProducer')
def test_get_producer_success(mock_kafka):
    # Wir simulieren, dass KafkaProducer erfolgreich erstellt wird
    mock_instance = MagicMock()
    mock_kafka.return_value = mock_instance
    
    producer = get_producer()
    
    assert producer == mock_instance