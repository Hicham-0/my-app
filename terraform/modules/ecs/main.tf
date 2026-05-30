# ── CloudWatch Log Group ───────────────────────────────────────
# Les logs de l'application iront ici
resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${var.project}-${var.environment}"
  retention_in_days = 7 # garde 7 jours de logs — économie de coût

  tags = {
    Name        = "/ecs/${var.project}-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Security Group ECS Tasks ───────────────────────────────────
# Les tasks ECS acceptent le trafic UNIQUEMENT depuis l'ALB
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project}-${var.environment}-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB only"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
    # ↑ UNIQUEMENT depuis le SG de l'ALB — jamais depuis internet
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    # ↑ nécessaire pour pull ECR, écrire CloudWatch, etc.
  }

  tags = {
    Name        = "${var.project}-${var.environment}-ecs-tasks-sg"
    Project     = var.project
    Environment = var.environment
  }
}

# ── ECS Cluster ────────────────────────────────────────────────
resource "aws_ecs_cluster" "main" {
  name = "${var.project}-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled" # métriques détaillées dans CloudWatch
  }

  tags = {
    Name        = "${var.project}-${var.environment}-cluster"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Task Definition ────────────────────────────────────────────
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.project}-${var.environment}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc" # obligatoire pour Fargate
  cpu                      = 256      # 0.25 vCPU — minimum Fargate
  memory                   = 512      # 512 MB — minimum Fargate

  execution_role_arn = var.execution_role_arn
  task_role_arn      = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = "${var.ecr_repo_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "APP_VERSION", value = var.app_version },
        { name = "ENVIRONMENT", value = var.environment },
        { name = "DEPLOY_COLOR", value = "blue" },
        { name = "AWS_REGION", value = var.aws_region }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.main.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name        = "${var.project}-${var.environment}-task"
    Project     = var.project
    Environment = var.environment
  }
}

# ── ECS Service ────────────────────────────────────────────────
resource "aws_ecs_service" "main" {
  name            = "${var.project}-${var.environment}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = 2 # 2 tasks — une par AZ
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false # subnets privés — pas d'IP publique
  }

  load_balancer {
    target_group_arn = var.target_group_blue_arn
    container_name   = var.container_name
    container_port   = 8080
  }

  deployment_controller {
    type = "CODE_DEPLOY" # délègue les déploiements à CodeDeploy
  }

  lifecycle {
    ignore_changes = [
      task_definition, # CodeDeploy met à jour la task definition
      load_balancer    # CodeDeploy gère le routing Blue/Green
    ]
  }

  depends_on = [var.target_group_blue_arn]

  tags = {
    Name        = "${var.project}-${var.environment}-service"
    Project     = var.project
    Environment = var.environment
  }
}