# ── S3 Bucket — artifacts CodePipeline ────────────────────────
resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.project}-${var.environment}-pipeline-artifacts"
  force_destroy = true

  tags = {
    Name        = "${var.project}-${var.environment}-pipeline-artifacts"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ── GitHub Connection (CodeStar) ───────────────────────────────
resource "aws_codestarconnections_connection" "github" {
  name          = "${var.project}-${var.environment}-github"
  provider_type = "GitHub"
}

# ── CodeBuild Project ──────────────────────────────────────────
resource "aws_codebuild_project" "main" {
  name          = "${var.project}-${var.environment}-build"
  description   = "Build, test and push Docker image to ECR"
  service_role  = var.codebuild_role_arn
  build_timeout = 20

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true # nécessaire pour docker build

    environment_variable {
      name  = "ECR_URI"
      value = var.ecr_uri
    }

    environment_variable {
      name  = "ECR_REPO"
      value = var.ecr_repository_name
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.aws_account_id
    }

    environment_variable {
      name  = "PROJECT"
      value = var.project
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }
  }






  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  tags = {
    Name        = "${var.project}-${var.environment}-build"
    Project     = var.project
    Environment = var.environment
  }
}

# ── CodeDeploy Application ─────────────────────────────────────
resource "aws_codedeploy_app" "main" {
  name             = "${var.project}-${var.environment}-app"
  compute_platform = "ECS"
}

# ── CodeDeploy Deployment Group ────────────────────────────────
resource "aws_codedeploy_deployment_group" "main" {
  app_name               = aws_codedeploy_app.main.name
  deployment_group_name  = "${var.project}-${var.environment}-dg"
  service_role_arn       = var.codedeploy_role_arn
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
    # rollback automatique si le déploiement échoue
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
      # bascule immédiatement après validation du health check
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
      # garde l'ancienne version 5 minutes — rollback possible pendant ce délai
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = var.ecs_cluster_name
    service_name = var.ecs_service_name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [var.listener_http_arn]
      }

      test_traffic_route {
        listener_arns = [var.listener_test_arn]
      }

      target_group {
        name = var.target_group_blue_name
      }

      target_group {
        name = var.target_group_green_name
      }
    }
  }
}

# ── CodePipeline ───────────────────────────────────────────────
resource "aws_codepipeline" "main" {
  name          = "${var.project}-${var.environment}-pipeline"
  role_arn      = var.codepipeline_role_arn
  pipeline_type = "V2"
  trigger {
    provider_type = "CodeStarSourceConnection"
    git_configuration {
      source_action_name = "GitHub_Source"
      push {
        branches {
          includes = ["main"]
        }
      }
    }
  }

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  # ── Stage 1 : Source ────────────────────────────────────────
  stage {
    name = "Source"

    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = var.github_repo
        BranchName       = var.github_branch
        DetectChanges    = "true"
      }
    }
  }

  # ── Stage 2 : Build ─────────────────────────────────────────
  stage {
    name = "Build"

    action {
      name             = "Build_and_Push"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.main.name
      }
    }
  }

  # ── Stage 3 : Deploy ────────────────────────────────────────
  stage {
    name = "Deploy"

    action {
      name            = "Blue_Green_Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      version         = "1"
      input_artifacts = ["build_output"]

      configuration = {
        ApplicationName                = aws_codedeploy_app.main.name
        DeploymentGroupName            = aws_codedeploy_deployment_group.main.deployment_group_name
        TaskDefinitionTemplateArtifact = "build_output"
        TaskDefinitionTemplatePath     = "taskdef.json"
        AppSpecTemplateArtifact        = "build_output"
        AppSpecTemplatePath            = "appspec.yaml"
        Image1ArtifactName             = "build_output"
        Image1ContainerName            = "IMAGE_URI"
      }
    }
  }

  tags = {
    Name        = "${var.project}-${var.environment}-pipeline"
    Project     = var.project
    Environment = var.environment
  }
}