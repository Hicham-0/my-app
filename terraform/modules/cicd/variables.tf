variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "github_repo" {
  type    = string
  default = "Hicham-0/my-app"
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "ecr_repository_url" {
  type = string
}

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

variable "codebuild_role_arn" {
  type = string
}

variable "codepipeline_role_arn" {
  type = string
}

variable "codedeploy_role_arn" {
  type = string
}

variable "target_group_blue_name" {
  type = string
}

variable "target_group_green_name" {
  type = string
}

variable "listener_http_arn" {
  type = string
}

variable "listener_test_arn" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ecs_tasks_security_group_id" {
  type = string
}