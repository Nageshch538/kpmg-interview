# ---- AMI Settings ----
variable "ami_name_pattern" {
  description = "AMI name filter pattern"
  type        = string
}

variable "architecture" {
  description = "AMI architecture type (e.g., x86_64 or arm64)"
  type        = string
}

# ---- EC2 Instance Settings ----
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "public_key_path" {
  description = "Path to your local public SSH key"
  type        = string
}

variable "ec2_public_key" {
  description = "The public SSH key string used for EC2 key pair"
  type        = string
}
# ---- Docker and App ----
variable "docker_image" {
  description = "Docker image to run in user data"
  type        = string
}

# ---- Auto Scaling Group ----
variable "asg_name" {
  description = "Name of the Auto Scaling Group"
  type        = string
}

# ---- Launch Template ----
variable "launch_template_name" {
  description = "Name of the EC2 Launch Template"
  type        = string
}

variable "spot_max_price" {
  description = "Max price for the spot instance"
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID for ECR image"
  type        = string
}

variable "app_name" {
  description = "Application name, used for naming resources"
  type        = string
  default     = "kpmg-challenge1"
}

variable "app_port" {
  description = "Port on which the container listens"
  type        = number
  default     = 5000
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-west-2"
}

# ---- Backend Configuration ----
variable "backend_bucket" {
  description = "Name of the S3 bucket for Terraform backend state"
  type        = string
}

variable "backend_key" {
  description = "Key path for the state file in the S3 bucket"
  type        = string
}

variable "backend_region" {
  description = "AWS region where the backend S3 bucket and DynamoDB table are located"
  type        = string
}

variable "backend_dynamodb_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
}