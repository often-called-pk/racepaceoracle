#!/usr/bin/env python3
# deploy.py - Script for deploying the F1 Telemetry WebApp to AWS

import os
import sys
import logging
import argparse
import subprocess
import shutil
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger('deploy')

# Define paths
SCRIPT_DIR = Path(os.path.dirname(os.path.abspath(__file__)))
ROOT_DIR = SCRIPT_DIR.parent
TERRAFORM_DIR = ROOT_DIR / 'terraform'
LAMBDA_DIR = ROOT_DIR / 'lambda_functions'
DIST_DIR = ROOT_DIR / 'dist'
BUILD_SCRIPT = SCRIPT_DIR / 'build_lambdas.py'

def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description='Deploy the F1 Telemetry WebApp to AWS')
    parser.add_argument('--stage', type=str, default='dev',
                        help='Deployment stage (dev, staging, prod)')
    parser.add_argument('--region', type=str, default='us-east-1',
                        help='AWS region to deploy to')
    parser.add_argument('--deploy-webapp', action='store_true', 
                        help='Deploy the webapp frontend to S3 and CloudFront')
    parser.add_argument('--skip-lambda-build', action='store_true',
                        help='Skip building Lambda functions')
    parser.add_argument('--tfvars-file', type=str, 
                        help='Path to Terraform variables file')
    parser.add_argument('--init-only', action='store_true',
                        help='Only initialize Terraform')
    parser.add_argument('--plan-only', action='store_true',
                        help='Only create Terraform plan')
    parser.add_argument('--destroy', action='store_true',
                        help='Destroy the deployed infrastructure')
    
    return parser.parse_args()

def run_command(cmd, cwd=None, check=True):
    """Run a shell command"""
    logger.info(f"Running command: {' '.join(cmd)}")
    try:
        result = subprocess.run(
            cmd, 
            cwd=cwd, 
            check=check, 
            stdout=subprocess.PIPE, 
            stderr=subprocess.PIPE,
            universal_newlines=True
        )
        logger.info(result.stdout)
        if result.stderr:
            logger.warning(result.stderr)
        return result
    except subprocess.CalledProcessError as e:
        logger.error(f"Command failed: {e.cmd}")
        logger.error(e.stderr)
        raise

def build_lambda_functions():
    """Build Lambda functions"""
    logger.info("Building Lambda functions...")
    
    if not BUILD_SCRIPT.exists():
        logger.error(f"Build script not found: {BUILD_SCRIPT}")
        return False
    
    try:
        run_command([sys.executable, str(BUILD_SCRIPT)], cwd=ROOT_DIR)
        logger.info("Lambda functions built successfully")
        return True
    except Exception as e:
        logger.error(f"Failed to build Lambda functions: {str(e)}")
        return False

def run_terraform_commands(args):
    """Run Terraform commands based on the provided arguments"""
    if not TERRAFORM_DIR.exists():
        logger.error(f"Terraform directory not found: {TERRAFORM_DIR}")
        return False
    
    # Define Terraform variables
    tf_vars = {
        'stage': args.stage,
        'region': args.region,
        'deploy_webapp': str(args.deploy_webapp).lower()
    }
    
    # Initialize Terraform
    logger.info("Initializing Terraform...")
    init_cmd = ['terraform', 'init']
    run_command(init_cmd, cwd=TERRAFORM_DIR)
    
    if args.init_only:
        logger.info("Terraform initialization completed. Exiting as requested.")
        return True
    
    # Create var file arguments
    var_args = []
    for key, value in tf_vars.items():
        var_args.extend(['-var', f'{key}={value}'])
    
    if args.tfvars_file:
        var_args.extend(['-var-file', args.tfvars_file])
    
    # Plan command
    plan_cmd = ['terraform', 'plan']
    plan_cmd.extend(var_args)
    
    # Create Terraform plan
    logger.info("Creating Terraform plan...")
    run_command(plan_cmd, cwd=TERRAFORM_DIR)
    
    if args.plan_only:
        logger.info("Terraform plan completed. Exiting as requested.")
        return True
    
    # Apply or destroy
    if args.destroy:
        logger.warning("Destroying infrastructure...")
        destroy_cmd = ['terraform', 'destroy', '-auto-approve']
        destroy_cmd.extend(var_args)
        run_command(destroy_cmd, cwd=TERRAFORM_DIR)
        logger.info("Infrastructure destroyed successfully")
    else:
        logger.info("Applying Terraform configuration...")
        apply_cmd = ['terraform', 'apply', '-auto-approve']
        apply_cmd.extend(var_args)
        run_command(apply_cmd, cwd=TERRAFORM_DIR)
        logger.info("Terraform apply completed successfully")
    
    return True

def main():
    """Main function to orchestrate deployment"""
    args = parse_args()
    
    logger.info(f"Starting deployment for stage: {args.stage}, region: {args.region}")
    
    # Check for AWS credentials
    if (not os.environ.get('AWS_ACCESS_KEY_ID') or 
        not os.environ.get('AWS_SECRET_ACCESS_KEY')):
        logger.warning("AWS credentials not found in environment variables")
        logger.warning("Make sure you've configured AWS credentials properly")
    
    # Build Lambda functions if needed
    if not args.skip_lambda_build:
        if not build_lambda_functions():
            logger.error("Failed to build Lambda functions. Exiting.")
            return 1
    else:
        logger.info("Skipping Lambda function build as requested")
    
    # Run Terraform commands
    try:
        success = run_terraform_commands(args)
        if not success:
            logger.error("Terraform deployment failed")
            return 1
    except Exception as e:
        logger.error(f"Error running Terraform: {str(e)}")
        return 1
    
    logger.info("Deployment completed successfully!")
    return 0

if __name__ == "__main__":
    sys.exit(main())