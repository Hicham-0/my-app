data "aws_caller_identity" "current" {}

module "vpc" {
  source      = "./modules/vpc"
  project     = var.project
  environment = var.environment
  vpc_cidr    = var.vpc_cidr
}

module "iam" {
  source      = "./modules/iam"
  project     = var.project
  environment = var.environment
}

module "ecr" {
  source      = "./modules/ecr"
  project     = var.project
  environment = var.environment
}

module "alb" {
  source            = "./modules/alb"
  project           = var.project
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
}

module "ecs" {
  source                = "./modules/ecs"
  project               = var.project
  environment           = var.environment
  aws_region            = var.aws_region
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  alb_security_group_id = module.alb.security_group_id
  target_group_blue_arn = module.alb.target_group_blue_arn
  execution_role_arn    = module.iam.ecs_execution_role_arn
  task_role_arn         = module.iam.ecs_task_role_arn
  ecr_repo_url          = module.ecr.repository_url
  app_version           = var.app_version
}

module "cicd" {
  source = "./modules/cicd"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region

  github_repo   = "Hicham-0/my-app"
  github_branch = "main"

  ecr_repository_url = module.ecr.repository_url
  ecs_cluster_name   = module.ecs.cluster_name
  ecs_service_name   = module.ecs.service_name

  codebuild_role_arn    = module.iam.codebuild_role_arn
  codepipeline_role_arn = module.iam.codepipeline_role_arn
  codedeploy_role_arn   = module.iam.codedeploy_role_arn

  target_group_blue_name  = module.alb.target_group_blue_name
  target_group_green_name = module.alb.target_group_green_name
  listener_http_arn       = module.alb.listener_http_arn
  listener_test_arn       = module.alb.listener_test_arn

  private_subnet_ids          = module.vpc.private_subnet_ids
  ecs_tasks_security_group_id = module.ecs.ecs_tasks_security_group_id

  ecr_uri             = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  ecr_repository_name = module.ecr.repository_name
  aws_account_id      = data.aws_caller_identity.current.account_id
}