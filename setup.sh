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

# ---------------------------------------------------------
# Secrets erstellen (Sicherheit für Open Source) 🔐
# ---------------------------------------------------------
echo "🔐 Erstelle Secrets..."

DB_PASSWORD="admin"

# 1. Secret für die Datenbank selbst (im Namespace 'database')
kubectl create secret generic db-credentials \
  --namespace database \
  --from-literal=password="$DB_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

# 2. Secret für den Spark-Processor (im Namespace 'processing')
kubectl create secret generic db-credentials \
  --namespace processing \
  --from-literal=password="$DB_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "   ✅ Secrets in 'database' und 'processing' angelegt."

# 4. ArgoCD installieren
echo "🐙 Installiere ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side --force-conflicts

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
spec:
  ingressClassName: traefik
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

# 9. NEU: Datenbank warten, initialisieren & PRÜFEN
echo "🗄️  Initialisiere Datenbank (Warte auf Pod)..."

# Kurz warten, damit K8s die Ressourcen anlegen kann
sleep 5

# 1. Warten, bis der Container physisch läuft (Kubernetes Ebene)
if kubectl wait --for=condition=ready pod -l app=postgres -n database --timeout=180s >/dev/null 2>&1; then
    
    # Pod Namen holen
    DB_POD=$(kubectl get pod -n database -l app=postgres -o jsonpath="{.items[0].metadata.name}")
    echo "   ...Pod $DB_POD ist gestartet."

    if [ -f "infrastructure/db/init_db.sql" ]; then
        # 2. Retry-Loop: Warten bis Postgres intern bereit ist
        echo "   ...Warte auf Datenbank-Verbindung..."
        MAX_RETRIES=30
        COUNT=0
        SUCCESS=false

        while [ $COUNT -lt $MAX_RETRIES ]; do
            # WICHTIG: Hier prüfen wir auf die DB 'flight_data', nicht 'postgres'
            if kubectl exec -n database $DB_POD -- psql -U postgres -d flight_data -c "SELECT 1" >/dev/null 2>&1; then
                SUCCESS=true
                break
            fi
            sleep 2
            COUNT=$((COUNT+1))
        done

        if [ "$SUCCESS" = true ]; then
            echo "   ✅ Verbindung steht! Kopiere & führe SQL aus..."
            
            # SQL kopieren
            kubectl cp infrastructure/db/init_db.sql database/$DB_POD:/tmp/init_db.sql
            
            # SQL ausführen (gegen flight_data!)
            kubectl exec -n database $DB_POD -- psql -U postgres -d flight_data -f /tmp/init_db.sql >/dev/null 2>&1
            
            echo "   ------------------------------------------------"
            echo "   📊 STATUS REPORT (Tabellen in DB 'flight_data'):"
            # DEIN BEFEHL ZUR KONTROLLE (gegen flight_data!):
            kubectl exec -n database $DB_POD -- psql -U postgres -d flight_data -c "\dt"
            echo "   ------------------------------------------------"
            
        else
            echo "   ❌ Timeout: Postgres hat nicht geantwortet."
        fi
    else
        echo "   ⚠️ Datei 'infrastructure/db/init_db.sql' nicht gefunden."
    fi
else
    echo "   ⚠️ Timeout: Datenbank-Pod wurde nicht bereit."
fi

echo "------------------------------------------------"
echo "🎉 FERTIG! Alles läuft vollautomatisch."
echo "🌍 ArgoCD URL: http://localhost:8080"
echo "👤 User:       admin"
echo -n "🔑 Password:   "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo "------------------------------------------------"