# kpmg-interview# Demo app deployment

Convert the Flask-based application into a Docker image
Push it to ECR
Launch it on ECS
We’ll build a serverless CI/CD pipeline, step by step!

Requirements
To successfully follow the steps in this article, make sure you have the following accounts, tools, and prerequisite knowledge:

Accounts & Cloud Environment
GitHub account — for repository and GitHub Actions usage
AWS account — with sufficient permissions to access ECR, ECS, and IAM
🛠️ Required Tools (must be installed and configured locally)
Git — for version control
Docker Engine — to build and test Docker images
AWS CLI — to interact with AWS services via terminal (AWS credentials)
Technologies Used
GitHub Actions → Automates CI/CD workflows
Docker → Containerizes the Flask application
Amazon ECR → Stores Docker images
Amazon ECS (Fargate) → Runs containers without managing servers
IAM → Manages secure access