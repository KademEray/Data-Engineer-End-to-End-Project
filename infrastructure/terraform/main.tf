# 1. Namespaces erstellen
resource "kubernetes_namespace_v1" "namespaces" {
  for_each = toset(["argocd", "kafka", "processing", "airflow", "database", "superset"])
  
  metadata {
    name = each.key
  }
}

# 2. ArgoCD installieren
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "6.7.0"
  
  # Namespace Zuweisung
  namespace  = kubernetes_namespace_v1.namespaces["argocd"].metadata[0].name

  # Warten auf Namespaces
  depends_on = [kubernetes_namespace_v1.namespaces]

  # Configuration via YAML (Best Practice)
  values = [
    yamlencode({
      # Global settings
      "redis-ha" = { # Anführungszeichen wichtig wegen "-"
        enabled = false
      }
      
      controller = {
        replicas = 1
      }

      repoServer = {
        replicas = 1
      }

      server = {
        replicas = 1
        extraArgs = ["--insecure"] # Hier zusammengeführt!
      }
    })
  ]
}