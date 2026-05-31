# ── ECS Execution Role ─────────────────────────────────────────
# Utilisé par ECS pour lancer les tâches (pull image, logs...)

resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project}-${var.environment}-ecs-execution-role"

  # Trust policy — qui peut assumer ce rôle ?
  # Réponse : ECS (le service qui lance les conteneurs)
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-ecs-execution-role"
    Project     = var.project
    Environment = var.environment
  }
}

# Politique AWS managée — couvre ECR pull + CloudWatch logs
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ── ECS Task Role ──────────────────────────────────────────────
# Utilisé par TON APPLICATION pendant qu'elle tourne

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project}-${var.environment}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-ecs-task-role"
    Project     = var.project
    Environment = var.environment
  }
}

# Politique custom pour le Task Role
# Pour l'instant : CloudWatch logs uniquement
resource "aws_iam_role_policy" "ecs_task_role_policy" {
  name = "${var.project}-${var.environment}-ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ── CodeDeploy Role ────────────────────────────────────────────
# Utilisé par CodeDeploy pour manipuler l'ALB et ECS

resource "aws_iam_role" "codedeploy_role" {
  name = "${var.project}-${var.environment}-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "codedeploy.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-codedeploy-role"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "codedeploy_role_policy" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# ── CodeBuild Role ─────────────────────────────────────────────
# Utilisé par CodeBuild pour builder et pusher sur ECR

resource "aws_iam_role" "codebuild_role" {
  name = "${var.project}-${var.environment}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "codebuild.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-codebuild-role"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "${var.project}-${var.environment}-codebuild-policy"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR — push et pull d'images
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      },
      # CloudWatch Logs — logs de build
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      # S3 — artifacts CodePipeline
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetObjectVersion"
        ]
        Resource = "*"
      },

      # codebuild pour savoir le current target group et listeners
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeLoadBalancers"
        ]
        Resource = "*"
      }
    ]
  })
}

# ── CodePipeline Role ──────────────────────────────────────────
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.project}-${var.environment}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "codepipeline.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-codepipeline-role"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.project}-${var.environment}-codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:RegisterApplicationRevision",
          "codedeploy:GetDeploymentConfig",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService",
          "iam:PassRole",
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "codestar-connections:UseConnection"
        ]
        Resource = "*"
      }
    ]
  })
}