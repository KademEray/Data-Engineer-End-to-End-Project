1. Implementation Plan (Architektur & Flow)
Core Stack:

Host: DevContainer (Docker-in-Docker)

Cluster: K3d (Kubernetes in Docker)

IaC: Terraform (Deployt Helm Charts in K3d)

Apps: Kafka (Strimzi), Spark, Airflow, Postgres, Superset

Data Pipeline Flow: OpenSky API -> Python Producer -> Kafka Topic -> Spark Streaming -> PostgreSQL -> Superset


##Start

./setup.sh

kubectl apply -f infrastructure/k8s/root-app.yaml