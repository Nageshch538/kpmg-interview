terraform {
  backend "s3" {
    bucket       = "flaskapp-terraformstate-bucket" # hardcoded since variables can't be used here
    key          = "dev/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
    encrypt      = true
  }
}

# Get the latest Amazon Linux 2023 AMI
data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = [var.ami_name_pattern]
  }

  filter {
    name   = "architecture"
    values = [var.architecture]
  }
}

# EC2 Key Pair
resource "aws_key_pair" "Ec2_key" {
  key_name   = "Ec2-key"
  public_key = var.ec2_public_key
}

# EC2 Standalone Instance
resource "aws_instance" "this" {
  ami                    = data.aws_ami.latest_amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.alb_sg.id]
  key_name               = aws_key_pair.Ec2_key.key_name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              service docker start
              usermod -a -G docker ec2-user
              docker run -d -p 5000:5000 ${var.docker_image}
              EOF

  tags = {
    Name = "flask-dev-standalone"
  }
}

# Launch Template for Auto Scaling
resource "aws_launch_template" "flask_app" {
  name          = var.launch_template_name
  image_id      = data.aws_ami.latest_amazon_linux.id
  instance_type = var.instance_type

  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price                      = var.spot_max_price
      spot_instance_type             = "one-time"
      instance_interruption_behavior = "terminate"
    }
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.alb_sg.id]
  }

  key_name  = aws_key_pair.Ec2_key.key_name
  user_data = filebase64("userdata.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "flask-app-ec2"
    }
  }
}

/*# Auto Scaling Group
resource "aws_autoscaling_group" "flask_app-asg" {
  name                = var.asg_name
  max_size            = 1
  min_size            = 1
  desired_capacity    = 1
  target_group_arns   = [aws_lb_target_group.new_flask_app.arn]
  vpc_zone_identifier = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.flask_app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = var.asg_name
    propagate_at_launch = true
  }
}


# Security Group allowing HTTP inbound (adjust as needed)
resource "aws_security_group" "ecs_sg" {
  name        = "${var.app_name}-sg"
  description = "Allow inbound HTTP and ephemeral ports"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   =  5000
    to_port     =  5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}*/
# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-ecs-cluster"
}

# IAM Role and Policy for ECS Task Execution (required for ECR pull)
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.app_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy_attachment" "ecs_task_execution_role_policy" {
  name       = "${var.app_name}-ecs-task-execution-role-policy-attach"
  roles      = [aws_iam_role.ecs_task_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "task" {
  family                   = "${var.app_name}-task"
  cpu                      = "512"
  memory                   = "1024"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "flaskapp-container"
      image     = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.app_name}:latest"
      essential = true
      portMappings = [{
        containerPort = var.app_port
        protocol      = "tcp"
      }]
      environment = [
        # Add env vars if any
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.log_group.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = var.app_name
        }
      }
    }
  ])
}


# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "log_group" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = 7
}

# ECS Service
resource "aws_ecs_service" "service" {
  name            = "${var.app_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_task_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.flask_tg.arn
    container_name   = "flaskapp-container"
    container_port   = var.app_port
  }

  depends_on = [
    aws_lb_listener.http_listener
  ]
}

/*# S3 Bucket for Remote State
resource "aws_s3_bucket" "tf_state" {
  bucket = var.backend_bucket
}

resource "aws_s3_bucket_versioning" "tf_state_versioning" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "tf_lock" {
  name         = var.backend_dynamodb_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
} 

# Terraform enhancements: CloudWatch, WAF, and Secrets Manager integration
# These modules assume your base infrastructure (ECS, ALB, IAM, etc.) is already provisioned.

# -----------------------------------
# 1. CloudWatch Log Group for ECS logs
# -----------------------------------
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/flaskapp"
  retention_in_days = 7
}

# IAM policy for ECS Task Role to push logs to CloudWatch
resource "aws_iam_policy" "ecs_logs_policy" {
  name        = "ecs-logs-policy"
  description = "Policy for ECS tasks to push logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_logs_policy_attach" {
  role       = var.ecs_task_execution_role_name
  policy_arn = aws_iam_policy.ecs_logs_policy.arn
}

# -----------------------------------
# 2. AWS WAF WebACL
# -----------------------------------
resource "aws_wafv2_web_acl" "flask_waf" {
  name        = "flaskapp-waf"
  scope       = "REGIONAL"
  description = "WAF for Flask ALB"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "flaskapp-waf"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSet"
    }
  }
}

resource "aws_wafv2_web_acl_association" "alb_waf_association" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.flask_waf.arn
}

# -----------------------------------
# 3. Secrets Manager for app secrets
# -----------------------------------
resource "aws_secretsmanager_secret" "flask_secret" {
  name        = "flaskapp/secret"
  description = "Secrets for Flask application"
}

resource "aws_secretsmanager_secret_version" "flask_secret_value" {
  secret_id     = aws_secretsmanager_secret.flask_secret.id
  secret_string = jsonencode({
    db_username = "admin",
    db_password = "SuperSecurePassword123"
  })
}

# IAM permission for ECS task to read secret
resource "aws_iam_policy" "secrets_access" {
  name        = "flask-secrets-access"
  description = "Allow ECS task to access Secrets Manager secret"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "secretsmanager:GetSecretValue"
        ],
        Resource = aws_secretsmanager_secret.flask_secret.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_secret_policy_attach" {
  role       = var.ecs_task_execution_role_name
  policy_arn = aws_iam_policy.secrets_access.arn
}*/



