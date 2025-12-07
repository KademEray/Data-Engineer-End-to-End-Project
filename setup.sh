#!/bin/bash
set -e

CLUSTER_NAME="opensky-cluster"

echo "🚀 --- OpenSky Infrastructure Setup (Clean Version) ---"

# 1. Cluster starten oder erstellen
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "✅ Cluster '$CLUSTER_NAME' gefunden."
    echo "🔄 Stelle sicher, dass der Cluster läuft..."
    k3d cluster start "$CLUSTER_NAME" >/dev/null 2>&1 || true
else
    echo "🆕 Erstelle Cluster '$CLUSTER_NAME'..."
    # WICHTIG: Wir mappen nur noch Port 8080 auf den Cluster-Ingress (Port 80)
    # Alle anderen Ports (8081, 5432) sind entfernt!
    k3d cluster create "$CLUSTER_NAME" \
        --api-port 6443 \
        -p "8080:80@loadbalancer" \
        --agents 1 \
        --wait
fi

# 2. Context setzen
k3d kubeconfig merge "$CLUSTER_NAME" --kubeconfig-switch-context

# 3. Namespaces erstellen
echo "📦 Erstelle Namespaces..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace kafka --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace processing --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace airflow --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace database --dry-run=client -o yaml | kubectl apply -f -

# 4. ArgoCD installieren
echo "🐙 Installiere ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 5. ArgoCD patchen (Sicherer JSON Patch)
echo "🔧 Konfiguriere ArgoCD für lokal..."
# Wir nutzen --type='json', um chirurgisch nur die 'args' Liste zu tauschen.
# Das lässt das 'image' und andere Felder unberührt.
kubectl patch deployment argocd-server -n argocd \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": ["/usr/local/bin/argocd-server", "--insecure", "--staticassets", "/shared/app"]}]'
  
# 6. Warten bis ArgoCD läuft
echo "⏳ Warte auf ArgoCD..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

echo "🎉 FERTIG! Cluster & ArgoCD laufen."
echo "🔐 Hole Passwort..."
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo