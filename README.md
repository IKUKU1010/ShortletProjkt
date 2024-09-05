# SHORTLET API-project2024

This brief documentation outlines the essential steps and considerations for setting up a CI/CD pipeline using GitHub Actions, providing a clear guide for automating the deployment of SHORTLET API app to an EKS cluster.


## CI/CD Pipeline with GitHub Actions for SHORTLET API App

## Prerequisites

- **GitHub Repository**: Ensure your project code is hosted on GitHub and contain all the required manifest files.

- **EKS Cluster**: An existing EKS (Elastic Kubernetes Service) cluster.

- **Terraform & Helm**: Scripts and configurations for provisioning infrastructure and deploying applications.

- **AWS CLI**: Configured with access to your AWS account.

- **kubectl**: Kubernetes CLI tool to manage your cluster.


## Step 1: Setup GitHub Actions Workflow

GitHub Actions Workflow is like a set of instructions or tasks that you want your project to automatically do whenever something happens in your code repository. These tasks can include things like running tests, building your code, deploying your application, or anything else you might want to automate.

Here’s a simple breakdown of a classic workflow:

**Trigger**: This is what starts the workflow. It could be something like pushing new code, opening a pull request, or even on a scheduled basis. Think of it as the event that says, “Hey, start doing these tasks!”

**Jobs**: These are the tasks that you want to run. Each job can do something specific, like testing your code to make sure it works, building your application, or deploying it to a server.

**Steps**: Each job is made up of steps. A step is a single action, like running a command or a script. Steps are what make up the job and are executed in order.

**Runners**: This is where your jobs are run. A runner is a server that GitHub provides to execute the steps in your workflow. It’s like the machine that actually does the work.

YAML File: The workflow is written in a YAML file, which is just a way to organize all these instructions in a text file. This file lives in your repository, usually in the .github/workflows/ directory.



In action Here’s how a workflow might look:

Trigger: Whenever you push code to the main branch;

Job 1: Test the Code: Run tests to make sure everything is working.

Job 2: Build the Site: If the tests pass, build the website.

Job 3: Deploy: Once the site is built, deploy it to your hosting service.

This entire process is automated by GitHub Actions, so once you set it up, you don’t have to manually do these tasks every time.


### This the Workflow file used on this project

```yaml
name: CI/CD Workflow

on:
  push:
    branches: ["main"]
  pull_request:
    branches: ["main"]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ vars.REGION }}

      - name: Install kubectl
        uses: azure/setup-kubectl@v3 

      - name: Install helm
        uses: azure/setup-helm@v4.2.0 

      - name: Create S3 bucket
        run: |
          if aws s3api head-bucket --bucket "shortlet-bucket" >/dev/null 2>&1; then
            echo "Bucket already exists, skipping creation."
          else
            echo "Bucket does not exist, creating it."
            aws s3 mb s3://"shortlet-bucket"
          fi

      - name: Create DynamoDB table
        run: |
          if aws dynamodb describe-table --table-name "shortlet-lock" >/dev/null 2>&1; then
            echo "DynamoDB table already exists, skipping creation."
          else
            aws dynamodb create-table \
              --table-name "shortlet-lock" \
              --attribute-definitions AttributeName=LockID,AttributeType=S \
              --key-schema AttributeName=LockID,KeyType=HASH \
              --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
          fi

      - name: Set up Terraform
        uses: hashicorp/setup-terraform@v2 

      - name: Deploy Terraform
        run: |
          terraform -chdir=terraform/ init
          terraform -chdir=terraform/ apply --auto-approve

      - name: Change Back to Project Root
        run: cd ..
      
      - name: Update kubeconfig
        run: |
          aws eks update-kubeconfig --name shortlet-CICD002 --region ${{ vars.REGION }}

      - name: Apply aws-auth ConfigMap
        run: kubectl apply -f aws-auth.yaml --validate=false
      
      - name: Create namespace shortlet
        run: kubectl get namespace shortlet || kubectl create namespace shortlet

      - name: Update kubeconfig
        run: |
          aws eks update-kubeconfig --name shortlet-CICD002 --region ${{ vars.REGION }}

      - name: Deploy application
        run: helm upgrade --install shortletapp helm/app --namespace shortlet

      - name: Deploy Let's Encrypt
        run: |
          helm repo add jetstack https://charts.jetstack.io --force-update
          helm repo update jetstack
          helm upgrade --install cert-manager jetstack/cert-manager \
            --namespace shortlet \
            --version v1.15.2 \
            --set crds.enabled=true

      - name: Delay
        run: sleep 10s

      - name: Deploy Nginx Ingress Controller
        run: |
          helm upgrade --install ingress-nginx oci://ghcr.io/nginxinc/charts/nginx-ingress --version 1.3.2 --namespace shortlet

      - name: Delay
        run: sleep 200s

      - name: Change Back to Project Root
        run: cd ..

      - name: Deploy Ingress Resources
        run: kubectl apply -f ingress.yml

      - name: Apply Cluster Issuer
        run: kubectl apply -f cluster-issuer.yml

      - name: Apply Certificate
        run: kubectl apply -f certificate.yml
               

Explanation

Checkout Code: Fetches your code from the repository.

Setup Terraform: Initializes and applies Terraform scripts to provision infrastructure (EKS cluster, networking, etc.).

AWS Credentials: Configures AWS credentials to interact with EKS.

Update kubeconfig: Updates the Kubernetes configuration file to manage the EKS cluster.

Install Helm: Adds necessary Helm repositories charts and updates them.

Deploy Application: Deploys the Shortlet app, Nginx ingress, and monitoring tools using Helm.

Apply Ingress: Configures the ingress resources to expose the application to the internet.

```
## Step 2: Setup Secrets in GitHub

Secrets and Variables are very vital in github actions and git-ops. It provides are secure wauy of storing private authetication data nd passwords in a github secure vault and passed as into your workflow like a library. 


For this project we will add the following secrets to the GitHub repository:

AWS_ACCESS_KEY_ID: user AWS IAM access key.
AWS_SECRET_ACCESS_KEY: user AWS IAM secret access key.
TF_API_TOKEN: Token for Terraform (if using Terraform Cloud).

These secrets allow GitHub Actions to securely interact with your AWS account and other services.


![github secrets](./images/github%20secrets.png)

<br>

![github secrets 2](./images/github%20secrets%202.png)


## Step 3: Trigger the Pipeline

After writing your manifest files and placing them in the correct branches of your repository, the workflow will then be triggered. 
The workflow pipeline is automatically triggered whenever there’s a push to the main branch. This automation ensures that your application is always up-to-date and running with the latest changes.


## Step 4: Monitor the Deployment

After triggering the pipeline, you can monitor the deployment progress in the "Actions" tab of your GitHub repository. Any issues or errors encountered during the process will be logged here, providing insights for troubleshooting.


This CI/CD pipeline setup automates the deployment of the SHORTLET app, ensuring a consistent and reliable process for getting changes into production.


Below are picture evidence of my work flow deployment:
<br>
![deployment of cicd pipeline](./images/cicd%20deploying.png)

<br>

![Successful deployment of cicd pipeline](./images/CICD%20done.png)

<br>



![cluster created via cicd pipeline](./images/cluster%20done.png)

<br>

<br>

![pods and services running](./images/pods%20and%20services%20runnin%20g%20perfectly.png)

<br>

### Time Server API is live
<br>

![Time Server API is live](./images/The%20API%20serving%20on%20web%20endpoint.png)

<br>
<br>

![Time Server API is live](./images/The%20API%20serving%20on%20web%20endpoint%202.png)






