# ───────── variables the caller must supply ─────────
variable "domain"         { type = string }
variable "chat_subdomain" { type = string }
variable "api_subdomain"  { type = string }
variable "zone_id"        { type = string }
variable "cert_arn"       { type = string }
variable "vpc_id"         { type = string }
variable "subnet_ids"     { type = list(string) }

# ───────── resources the module creates ─────────
resource "aws_lb" "dextec" {
  name               = "dexttec-alb"
  load_balancer_type = "application"
  subnets            = var.subnet_ids
}

resource "aws_lb_target_group" "gateway" {
  name     = "dexttec-gw-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.dextec.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.cert_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gateway.arn
  }
}

resource "aws_route53_record" "chat" {
  zone_id = var.zone_id
  name    = "${var.chat_subdomain}.${var.domain}"
  type    = "A"

  alias {
    name                   = aws_lb.dextec.dns_name
    zone_id                = aws_lb.dextec.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api" {
  zone_id = var.zone_id
  name    = "${var.api_subdomain}.${var.domain}"
  type    = "A"

  alias {
    name                   = aws_lb.dextec.dns_name
    zone_id                = aws_lb.dextec.zone_id
    evaluate_target_health = true
  }
}
# ─── Security‑group for the ALB ───────────────────────────────────
resource "aws_security_group" "alb_sg" {
  name        = "dexttec-alb-sg"
  description = "Allow HTTPS from anywhere"
  vpc_id      = var.vpc_id

  ingress {
    description      = "HTTPS from internet"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {                       # allow all outbound (default)
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = { Name = "dexttec-alb-sg" }
}

# ─── Attach the SG to the ALB ─────────────────────────────────────
resource "aws_lb" "dextec" {
  name               = "dexttec-alb"
  load_balancer_type = "application"
  subnets            = var.subnet_ids
  security_groups    = [aws_security_group.alb_sg.id]   # ← add this line
}