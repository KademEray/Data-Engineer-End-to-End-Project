# 🚀 Project Operations Cheat Sheet

## 🟢 1. Starten (Täglich)

Wenn du den DevContainer neu gestartet hast, führe diese Schritte nacheinander aus:

### 1. Cluster & ArgoCD hochfahren
Erstellt den Cluster und installiert ArgoCD.
```bash
./setup.sh
```

### 2. Die Anwendungen installieren (ArgoCD "Einschalten")
Sagt ArgoCD, dass es die Root-App und alle Unter-Apps (Kafka, Producer, etc.) laden soll.
```bash
kubectl apply -f infrastructure/k8s/root-app.yaml
```

### 3. Zugriff auf ArgoCD (UI)
Startet den Tunnel, damit du die Oberfläche im Browser siehst.
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

URL: https://localhost:8080

User: admin

Passwort abrufen:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

## 💻 2. Entwicklung & Deployment (GitOps Flow)
Wir nutzen CI-Push: GitHub Actions baut das Image und aktualisiert die Version in Git automatisch.

Ändere deinen Code (z.B. in src/producer/).

Pushe die Änderung:
```bash
git add .
git commit -m "feat: updated producer logic"
git push
```

Automatismus:

GitHub Actions baut das Docker Image.

GitHub Actions schreibt den neuen Tag in infrastructure/k8s/producer-manifests/kustomization.yaml.

ArgoCD erkennt die Änderung im Git und synct den Cluster (ca. 3 Min Delay oder manuell "Sync" klicken).

## 🔍 3. Kontrolle & Debugging
Status prüfen (Alles grün?)
```bash
kubectl get pods -A
```
Logs ansehen (Was macht der Producer?)
```bash
kubectl logs -l app=opensky-producer -n kafka -f
```
ArgoCD Application Status
```bash
kubectl get application -n argocd
```

## 🛠 4. Reset & Fehlerbehebung
Ein Deployment neu starten (Soft Reset)
Hilft, wenn ein Pod hängt oder du ein Update erzwingen willst (zieht das Image neu, falls latest verwendet wird).

```bash
kubectl rollout restart deployment opensky-producer -n kafka
```

Port 8080 ist belegt?
Fehler: address already in use. Lösung: Anderen Port nutzen.
```bash
kubectl port-forward svc/argocd-server -n argocd 8081:443
```

Manuelle Secrets (Nur falls Image NICHT Public ist)
Falls du doch wieder private Images nutzt:
```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=DEIN_USER \
  --docker-password=DEIN_TOKEN \
  --docker-email=DEIN_EMAIL \
  -n kafka
```

## 🧨 5. Löschen (Teardown)
Alles stoppen (Cluster löschen)
Löscht den kompletten k3d Cluster. Alle Daten in der Datenbank gehen verloren!
```bash
k3d cluster delete opensky-cluster
```