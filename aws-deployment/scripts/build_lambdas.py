#!/usr/bin/env python3
# build_lambdas.py - Script for packaging Lambda functions

import os
import sys
import shutil
import subprocess
import tempfile
import logging
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger('build_lambdas')

# Define paths
SCRIPT_DIR = Path(os.path.dirname(os.path.abspath(__file__)))
ROOT_DIR = SCRIPT_DIR.parent
LAMBDA_DIR = ROOT_DIR / 'lambda_functions'
DIST_DIR = ROOT_DIR / 'dist'

# Lambda functions to build
LAMBDA_FUNCTIONS = [
    'telemetry',
    'driver_data',
    'race_data',
]

def setup_directories():
    """Create necessary directories"""
    logger.info("Setting up directories...")
    os.makedirs(DIST_DIR, exist_ok=True)

def build_lambda_function(function_name):
    """Build a Lambda function package"""
    logger.info(f"Building Lambda function: {function_name}")
    
    function_dir = LAMBDA_DIR / function_name
    output_zip = DIST_DIR / f"{function_name}.zip"
    
    if not function_dir.exists():
        logger.error(f"Function directory not found: {function_dir}")
        return False
    
    # Create a temporary directory for packaging
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        
        # Copy function code
        for file in function_dir.glob('*.py'):
            shutil.copy(file, temp_path / file.name)
        
        # Check for requirements.txt
        requirements_file = function_dir / 'requirements.txt'
        if requirements_file.exists():
            logger.info(f"Installing dependencies for {function_name}...")
            
            # Install dependencies into the temporary directory
            try:
                subprocess.run(
                    [
                        sys.executable, 
                        '-m', 
                        'pip', 
                        'install', 
                        '-r', 
                        str(requirements_file),
                        '--target', 
                        temp_dir
                    ],
                    check=True,
                    capture_output=True
                )
            except subprocess.CalledProcessError as e:
                logger.error(f"Failed to install dependencies: {e.stderr.decode('utf-8')}")
                return False
        
        # Create zip file
        shutil.make_archive(str(output_zip).replace('.zip', ''), 'zip', temp_dir)
        
        if output_zip.exists():
            logger.info(f"Successfully created {output_zip}")
            return True
        else:
            logger.error(f"Failed to create {output_zip}")
            return False

def main():
    """Main function to build all Lambda functions"""
    logger.info("Starting Lambda function build process...")
    
    # Set up directories
    setup_directories()
    
    # Build each function
    success = True
    for function_name in LAMBDA_FUNCTIONS:
        if not build_lambda_function(function_name):
            logger.error(f"Failed to build {function_name}")
            success = False
    
    if success:
        logger.info("All Lambda functions built successfully!")
        return 0
    else:
        logger.error("Failed to build one or more Lambda functions")
        return 1

if __name__ == "__main__":
    sys.exit(main())