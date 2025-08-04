backend_bucket         = "flaskapp-terraformstate-bucket"
backend_key            = "dev/terraform.tfstate"
backend_region         = "eu-west-2"
backend_dynamodb_table = "my-terraform-lock-table"

ami_name_pattern = "al2023-ami-*-x86_64"
architecture     = "x86_64"

instance_type = "t3.micro"

public_key_path = "C:/Users/Admin/.ssh/id_ed25519.pub"

docker_image = "ncherukuri/flaskapp1:latest"

asg_name = "flask-dev-asg"

launch_template_name = "flask-dev-launch-template"

spot_max_price = "0.007"

aws_account_id = "389595560555"

app_name = "kpmg-challenge1"

app_port = 5000

# Networking Configuration