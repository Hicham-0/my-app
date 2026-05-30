# Blue/Green Deployment on AWS ECS Fargate

Application Node.js déployée avec une stratégie Blue/Green sur AWS ECS Fargate,
avec un pipeline CI/CD entièrement automatisé.

## Architecture

GitHub → CodePipeline → CodeBuild → ECR → CodeDeploy → ECS Fargate
↓
ALB (Blue/Green)

## Stack technique

| Composant | Technologie |
|---|---|
| Application | Node.js + Express |
| Conteneurisation | Docker |
| Registre d'images | Amazon ECR |
| Orchestration | Amazon ECS Fargate |
| CI/CD | CodePipeline + CodeBuild + CodeDeploy |
| Infrastructure | Terraform |
| Réseau | VPC + ALB |
| Monitoring | CloudWatch |

## Pipeline CI/CD

1. **Source** — push sur `main` déclenche le pipeline
2. **Build** — tests unitaires, build Docker, scan Trivy, push ECR
3. **Deploy** — déploiement Blue/Green via CodeDeploy

## Déploiement Blue/Green

- Zéro downtime — bascule instantanée du trafic
- Rollback automatique en cas d'échec
- Health checks via `/health` endpoint

## Prérequis

- AWS CLI configuré
- Terraform >= 1.0
- Docker
- Node.js >= 20

## Infrastructure

```bash
cd terraform
terraform init
terraform apply
```

## Application locale

```bash
cd app
npm install
npm test
docker build -t my-app:local .
docker run -p 8080:8080 my-app:local
```

## Endpoints

| Endpoint | Description |
|---|---|
| `GET /` | UI principale avec version et métadonnées |
| `GET /health` | Health check (utilisé par l'ALB) |
| `GET /info` | Métadonnées JSON (version, région, couleur) |