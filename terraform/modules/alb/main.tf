# ── Security Group ALB ─────────────────────────────────────────
# L'ALB accepte le trafic HTTP depuis internet
resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.environment}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Port 8080 — utilisé par CodeDeploy pendant le test du Green
  # avant la bascule du trafic
  ingress {
    description = "Test traffic for green group"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-alb-sg"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Application Load Balancer ──────────────────────────────────
resource "aws_lb" "main" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = false # public — accessible depuis internet
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  tags = {
    Name        = "${var.project}-${var.environment}-alb"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Target Group BLUE ──────────────────────────────────────────
# Reçoit le trafic de production (version actuelle)
resource "aws_lb_target_group" "blue" {
  name        = "${var.project}-${var.environment}-tg-blue"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # obligatoire pour Fargate (awsvpc mode)

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project}-${var.environment}-tg-blue"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Target Group GREEN ─────────────────────────────────────────
# Reçoit le trafic pendant le déploiement (nouvelle version)
resource "aws_lb_target_group" "green" {
  name        = "${var.project}-${var.environment}-tg-green"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project}-${var.environment}-tg-green"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Listener Port 80 ───────────────────────────────────────────
# Trafic de production — pointe sur BLUE au départ
# CodeDeploy le bascule vers GREEN lors du déploiement
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }

  lifecycle {
    ignore_changes = [default_action]
    # CodeDeploy modifie ce listener pendant le déploiement
    # Terraform ne doit pas écraser ces changements
  }
}

# ── Listener Port 8080 ─────────────────────────────────────────
# Listener de test — CodeDeploy l'utilise pour valider GREEN
# avant de basculer le trafic de production
resource "aws_lb_listener" "test" {
  load_balancer_arn = aws_lb.main.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green.arn
  }

  lifecycle {
    ignore_changes = [default_action]
  }
}