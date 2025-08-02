#!/bin/bash

# Variables
REGION="eu-west-2"
AWS_ACCOUNT_ID="389595560555"
REPO_NAME="kpmg-challenge1"
IMAGE_NAME="flaskapp"
TAG="v2"

# Build Docker image
docker build -t ${IMAGE_NAME}:${TAG} .

# Tag image for ECR
docker tag ${IMAGE_NAME}:${TAG} ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}/${IMAGE_NAME}:${TAG}

# Authenticate Docker to ECR
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

# Push Docker image to ECR
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}/${IMAGE_NAME}:${TAG}
