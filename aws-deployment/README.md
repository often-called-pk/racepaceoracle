# F1 Telemetry WebApp AWS Deployment

This repository contains the AWS deployment infrastructure for the F1 Telemetry WebApp, which provides real-time and historical telemetry data for Formula 1 races.

## Architecture Overview

This deployment creates a serverless architecture on AWS with the following components:

- **Frontend**: React-based SPA hosted on S3 and delivered through CloudFront
- **Backend API**: API Gateway with Lambda functions
- **Database**: DynamoDB tables for telemetry, driver, and lap data
- **Infrastructure**: Fully defined using Terraform for infrastructure-as-code

### AWS Services Used

- Amazon S3 (static website hosting)
- Amazon CloudFront (content delivery)
- Amazon API Gateway (RESTful API)
- AWS Lambda (serverless compute)
- Amazon DynamoDB (NoSQL database)
- AWS IAM (identity and access management)
- Amazon CloudWatch (monitoring and logging)
- AWS Route53 (optional - for custom domain)
- AWS Certificate Manager (optional - for SSL certificates)

## Prerequisites

Before deploying, ensure you have the following:

- [AWS CLI](https://aws.amazon.com/cli/) installed and configured
- [Terraform](https://www.terraform.io/downloads.html) v1.0.0 or higher
- [Python](https://www.python.org/downloads/) 3.8 or higher
- [pip](https://pip.pypa.io/en/stable/installation/) for Python package management

## Repository Structure

```
aws-deployment/
├── lambda_functions/       # Lambda function source code
│   ├── telemetry/         # Telemetry data Lambda
│   ├── driver_data/       # Driver data Lambda
│   └── race_data/         # Race data Lambda
├── scripts/               # Deployment scripts
│   ├── build_lambdas.py   # Script to build Lambda packages
│   └── deploy.py          # Main deployment script
├── terraform/             # Terraform IaC configuration
│   ├── api_gateway.tf     # API Gateway configuration
│   ├── cloudfront.tf      # CloudFront distribution
│   ├── dynamodb.tf        # DynamoDB tables
│   ├── iam.tf             # IAM roles and policies
│   ├── lambda.tf          # Lambda functions
│   ├── main.tf            # Main Terraform configuration
│   ├── outputs.tf         # Output values
│   ├── route53.tf         # DNS configuration (optional)
│   ├── s3.tf              # S3 buckets
│   ├── variables.tf       # Input variables
│   └── versions.tf        # Provider versions
└── dist/                  # Built artifacts (created during deployment)
```

## Deployment Instructions

### 1. Clone the Repository

Clone this repository to your local machine:

```bash
git clone <repository-url>
cd f1-telemetry-webapp-aws
```

### 2. Configure AWS Credentials

Ensure your AWS credentials are configured either through environment variables or the AWS CLI:

```bash
aws configure
```

Or set environment variables:

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"
```

### 3. Configure Deployment Variables (Optional)

Create a `terraform.tfvars` file in the `terraform/` directory to customize your deployment:

```hcl
region = "us-east-1"
stage = "dev"
environment = "development"
deploy_webapp = true

# Optional custom domain configuration
enable_custom_domain = false
custom_domain_name = "your-domain.com"

# Performance settings
read_capacity = 5
write_capacity = 5
lambda_memory_size = 128
api_throttling_rate_limit = 100
```

### 4. Make Scripts Executable

```bash
chmod +x scripts/build_lambdas.py
chmod +x scripts/deploy.py
```

### 5. Deploy the Infrastructure

Run the deployment script:

```bash
./scripts/deploy.py --stage dev --region us-east-1 --deploy-webapp
```

Options:
- `--stage`: Deployment stage (dev, staging, prod)
- `--region`: AWS region
- `--deploy-webapp`: Deploy the frontend webapp
- `--tfvars-file`: Path to a custom Terraform variables file
- `--skip-lambda-build`: Skip Lambda function building
- `--plan-only`: Only create a Terraform plan without applying
- `--init-only`: Only initialize Terraform
- `--destroy`: Destroy the deployed infrastructure

### 6. Deploy the Frontend

The webapp can be deployed using the S3 sync command provided in the Terraform outputs:

```bash
cf run terraform output -json -state=terraform/terraform.tfstate > outputs.json
export S3_BUCKET=$(jq -r '.webapp_bucket_name.value' outputs.json)
aws s3 sync ../f1_telemetry_webapp-main/build/ s3://$S3_BUCKET --delete
```

### 7. Testing the Deployment

After deployment, you can access your webapp via the CloudFront URL provided in the Terraform outputs:

```bash
terraform -chdir=terraform output cloudfront_domain_name
```

If you've configured a custom domain, you can access it directly using your domain name.

## Monitoring and Logging

- **CloudWatch Dashboards**: Created automatically for Lambda functions, API Gateway, and DynamoDB
- **CloudWatch Alarms**: Set up for errors and throttling events
- **CloudWatch Logs**: Available for all Lambda functions and API Gateway

## Security Considerations

- IAM roles follow the principle of least privilege
- CloudFront distribution is configured with secure headers
- API Gateway uses throttling to prevent abuse
- S3 buckets are not publicly accessible (access only through CloudFront)

## Cleanup

To remove all deployed resources:

```bash
./scripts/deploy.py --stage dev --region us-east-1 --destroy
```

## License

[MIT License](LICENSE)
