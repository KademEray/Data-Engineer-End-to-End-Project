variable "kubeconfig_path" {
  description = "Pfad zur Kubeconfig Datei"
  type        = string
  default     = "/home/vscode/.kube/config"
}

variable "kube_context" {
  description = "Der Name des Kubernetes Contexts"
  type        = string
  default     = "k3d-opensky-cluster"
}