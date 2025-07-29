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
resource "aws_autoscaling_group" "flask_app" {
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
*/