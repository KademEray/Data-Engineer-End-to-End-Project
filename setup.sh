#!/bin/bash
set -e # Bricht das Skript ab, wenn ein Fehler passiert

CLUSTER_NAME="opensky-cluster"

echo "🚀 --- OpenSky Infrastructure Setup ---"

# 1. Prüfen, ob der Cluster schon existiert
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "✅ Cluster '$CLUSTER_NAME' gefunden."
    
    # Versuchen zu starten (falls er gestoppt ist). 
    # '|| true' verhindert Fehler, falls er schon läuft.
    echo "🔄 Stelle sicher, dass der Cluster läuft..."
    k3d cluster start "$CLUSTER_NAME" >/dev/null 2>&1 || true
    
else
    echo "🆕 Kein Cluster gefunden. Erstelle '$CLUSTER_NAME'..."
    
    # Cluster erstellen mit Port-Mappings
    # 8080:80   -> Für Ingress (Webseiten wie Airflow)
    # 8081:8081 -> Reserve für ArgoCD UI Direktzugriff
    # 5432:5432 -> Für direkten Datenbankzugriff (Postgres)
    k3d cluster create "$CLUSTER_NAME" \
        --api-port 6443 \
        -p "8080:80@loadbalancer" \
        -p "8081:8081@loadbalancer" \
        -p "5432:5432@loadbalancer" \
        --agents 1 \
        --wait
        
    echo "✨ Cluster erfolgreich erstellt!"
fi

# 2. Kubectl Verbindung herstellen (Context setzen)
k3d kubeconfig merge "$CLUSTER_NAME" --kubeconfig-switch-context
echo "✅ Kubectl Context ist auf '$CLUSTER_NAME' gesetzt."

# 3. Warten, bis die internen Dienste (DNS) bereit sind
echo "⏳ Warte auf CoreDNS (System bereit)..."
kubectl wait --for=condition=ready pod -l k8s-app=kube-dns -n kube-system --timeout=60s

echo "🎉 Fertig! Dein Kubernetes Cluster läuft."
kubectl get nodes