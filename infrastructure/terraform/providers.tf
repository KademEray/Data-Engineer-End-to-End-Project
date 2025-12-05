terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9.0"
    }
  }
}

# Kubernetes Provider: Sagt Terraform explizit, welche Config es nehmen soll
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "k3d-opensky-cluster"
}

# Helm Provider: 
# Wir lassen ihn LEER. Er nutzt dann automatisch die Standard-Config (~/.kube/config),
# die wir im setup.sh Script bereits korrekt eingestellt haben.
provider "helm" {
  kubernetes = {
    config_path    = var.kubeconfig_path
    config_context = var.kube_context
  }
}