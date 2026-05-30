output "alb_dns_name" {
  description = "URL publique de l'application"
  value       = module.alb.dns_name
}

output "ecr_repository_url" {
  description = "URL du registre ECR"
  value       = module.ecr.repository_url
}

output "ecs_cluster_name" {
  description = "Nom du cluster ECS"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Nom du service ECS"
  value       = module.ecs.service_name
}

output "pipeline_name" {
  value = module.cicd.pipeline_name
}

output "github_connection_arn" {
  value = module.cicd.github_connection_arn
}