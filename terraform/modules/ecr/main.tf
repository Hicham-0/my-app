resource "aws_ecr_repository" "main" {
  name                 = "${var.project}-${var.environment}"
  image_tag_mutability = "MUTABLE"

  # Scan automatique à chaque push — détecte les vulnérabilités
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project}-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Lifecycle Policy ───────────────────────────────────────────
# Garde seulement les 10 dernières images — évite de payer pour du stockage inutile
resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Garde les 10 dernières images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}