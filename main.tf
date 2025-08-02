terraform {
  backend "s3" {
    bucket         = "flaskapp-terraformstate-bucket"   # hardcoded since variables can't be used here
    key            = "dev/terraform.tfstate"
    region         = "eu-west-2"
    use_lockfile = true
    encrypt        = true
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
resource "aws_key_pair" "my_key" {
  key_name   = "my-key"
  public_key = file(var.public_key_path)
}

# EC2 Standalone Instance
resource "aws_instance" "this" {
  ami                         = data.aws_ami.latest_amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  key_name                    = aws_key_pair.my_key.key_name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              service docker start
              usermod -a -G docker ec2-user
              docker run -d -p 8081:8081 ${var.docker_image}
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
    security_groups              = [aws_security_group.ec2_sg.id]
  }

  key_name  = aws_key_pair.my_key.key_name
  user_data = filebase64("userdata.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "flask-app-ec2"
    }
  }
}

# Auto Scaling Group
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



