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