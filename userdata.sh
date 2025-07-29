#!/bin/bash
# Update packages
yum update -y

# Install Docker
amazon-linux-extras install docker -y

# Start Docker service
service docker start

# Add ec2-user to docker group so docker can run without sudo
usermod -aG docker ec2-user

# Pull your Docker image
docker pull flaskapp1

# Run container mapping port 8080
docker run -d -p 8081:8081 flaskapp1
