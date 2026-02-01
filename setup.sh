#!/bin/bash
set -e

CLUSTER_NAME="opensky-cluster"

echo "🚀 --- OpenSky Infrastructure Setup (Final Polish) ---"

# 1. Cluster starten oder erstellen
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "✅ Cluster '$CLUSTER_NAME' gefunden."
    echo "🔄 Stelle sicher, dass der Cluster läuft..."
    k3d cluster start "$CLUSTER_NAME" >/dev/null 2>&1 || true
else
    echo "🆕 Erstelle Cluster '$CLUSTER_NAME'..."
    # Port 8080 (Host) -> Port 80 (Traefik Ingress)
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

# 5. ArgoCD patchen (Insecure Mode & Performance)
echo "🔧 Konfiguriere ArgoCD (Insecure Mode)..."
kubectl patch deployment argocd-server -n argocd \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": ["/usr/local/bin/argocd-server", "--insecure", "--staticassets", "/shared/app"]}]'

# 6. Warten bis ArgoCD bereit ist
echo "⏳ Warte auf ArgoCD..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# 7. Ingress erstellen (Modern & Clean)
echo "🌐 Erstelle Ingress Route für ArgoCD..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  # Annotation entfernt, da deprecated
spec:
  ingressClassName: traefik  # <-- Das ist der neue Weg!
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
EOF

# 8. Root-App direkt deployen 🚀
echo "🌱 Starte GitOps Apps (Root App)..."
if [ -f "infrastructure/k8s/root-app.yaml" ]; then
    kubectl apply -f infrastructure/k8s/root-app.yaml
else
    echo "⚠️ WARNUNG: 'infrastructure/k8s/root-app.yaml' nicht gefunden. Bitte manuell ausführen."
fi

echo "------------------------------------------------"
echo "🎉 FERTIG! Alles läuft vollautomatisch."
echo "🌍 ArgoCD URL: http://localhost:8080"
echo "👤 User:       admin"
echo -n "🔑 Password:   "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo "------------------------------------------------"