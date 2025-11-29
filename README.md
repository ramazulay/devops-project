# DevOps Project - Quick Guide

AWS EKS-based microservices platform with Jenkins CI/CD pipelines.

---


## 🚀 Quick Deployment

### Step 1: Check Prerequisites

```bash
./GET_STARTED.sh
```

**What it does:**
- Checks AWS CLI, Terraform/OpenTofu, kubectl, Python
- Verifies AWS credentials
- Creates `.env` file with your AWS account info

**Duration**: ~1 minute

---

### Step 2: Deploy Infrastructure

```bash
./deploy-infra.sh
```

**What it does:**
- Creates VPC with public/private subnets
- Deploys EKS Cluster (Kubernetes v1.32)
- Creates ECR registry, SQS queue, S3 bucket
- Sets up IAM roles with IRSA
- Configures kubectl to access the cluster
- Saves all resource info to `infrastructure-outputs.env`

**Duration**: ~15-20 minutes

**What you'll see:**
- Terraform will show you what it will create
- You'll need to type "yes" to confirm
- Progress updates as resources are created

---

### Step 3: Deploy Jenkins

```bash
cd jenkins
./deploy-jenkins.sh
```

**What it does:**
- Creates Jenkins namespace in Kubernetes
- Deploys Jenkins with persistent storage (20Gi)
- Creates LoadBalancer for external access
- Sets up IRSA for AWS permissions
- Enables Docker-in-Docker for building images

**Duration**: ~5 minutes

**What you'll see:**
- Jenkins pod being created
- LoadBalancer service getting an external URL
- Jenkins ready message with URL

---

## 🔧 Jenkins Setup & Configuration

### Step 1: Access Jenkins

```bash
# Get Jenkins URL
JENKINS_URL=$(kubectl get svc jenkins -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Jenkins URL: http://${JENKINS_URL}:8080"

# Get admin password
JENKINS_POD=$(kubectl get pods -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n jenkins $JENKINS_POD -- cat /var/jenkins_home/secrets/initialAdminPassword
```

**Copy the password**, then open the Jenkins URL in your browser.

---

### Step 2: Complete Jenkins Setup Wizard

1. **Unlock Jenkins**: Paste the admin password
2. **Customize Jenkins**: Click **"Install suggested plugins"**
3. **Wait for plugins** to install (~2-3 minutes)
4. **Create First Admin User**:
   - Username: `admin` (or your choice)
   - Password: (set a strong password)
   - Full name: Your name
   - Email: Your email
5. **Instance Configuration**: Keep the default URL
6. Click **"Start using Jenkins"**

---

### Step 3: Install Additional Plugins

1. Go to **Manage Jenkins** (left sidebar)
2. Click **Manage Plugins**
3. Click **Available** tab
4. Search and select these plugins:
   - ✅ **Docker Pipeline** (for building Docker images)
   - ✅ **Kubernetes** (for K8s deployments)
   - ✅ **AWS Steps** (for AWS operations)
   - ✅ **Git** (should already be installed)
   - ✅ **Pipeline** (should already be installed)
5. Click **"Install without restart"**
6. Wait for installation to complete

---

### Step 4: Configure Global Environment Variables

1. Go to **Manage Jenkins** → **Configure System**
2. Scroll to **Global properties**
3. Check **"Environment variables"**
4. Add these variables (get values from `infrastructure-outputs.env`):

```bash
# First, load the values
cd /path/to/devops-project
cat infrastructure-outputs.env
```

Add in Jenkins:
- Name: `AWS_REGION`, Value: `us-west-1`
- Name: `ECR_REGISTRY`, Value: `<your-account-id>.dkr.ecr.us-west-1.amazonaws.com`
- Name: `EKS_CLUSTER`, Value: `dev-CP-EKS-CLUSTER`
- Name: `SQS_QUEUE_URL`, Value: (from infrastructure-outputs.env)
- Name: `S3_BUCKET`, Value: (from infrastructure-outputs.env)

5. Click **Save** at the bottom

---

## 📦 Create Jenkins CI/CD Pipelines

We'll create 2 reusable pipelines: 1 for CI (build) and 1 for CD (deploy). Each pipeline uses parameters to select which service to work with.

### Pipeline 1: Microservices CI (Build & Push Images)

**Purpose**: Builds Docker images and pushes to ECR for any microservice

1. From Jenkins dashboard, click **"New Item"**
2. Enter name: `microservices-ci`
3. Select **"Pipeline"**
4. Click **OK**
5. In the configuration page:
   - **Description**: `Builds and pushes microservice Docker images to ECR`
   - Check **"This project is parameterized"**
   - Click **"Add Parameter"** → **"Choice Parameter"**
     - Name: `SERVICE`
     - Choices (one per line):
       ```
       email-processor
       sqs-processor
       ```
     - Description: `Which microservice to build`
   - Scroll to **Pipeline** section
   - **Definition**: Select **"Pipeline script from SCM"**
   - **SCM**: Select **"Git"**
   - **Repository URL**: `https://github.com/ramazulay/devops-project.git`
   - **Credentials**: The repo is public
   - **Branch Specifier**: `*/main`
   - **Script Path**: `jenkins/Jenkinsfile-CI`
6. Click **Save**

**What this pipeline does:**
- Checks out code from Git
- Determines which service to build based on `SERVICE` parameter
- Builds Docker image from the appropriate directory
- Logs into AWS ECR
- Tags image with build number and `latest`
- Pushes image to ECR

---

### Pipeline 2: Microservices CD (Deploy to Kubernetes)

**Purpose**: Deploys any microservice to EKS cluster

1. Click **"New Item"**
2. Enter name: `microservices-cd`
3. Select **"Pipeline"**
4. Click **OK**
5. In the configuration page:
   - **Description**: `Deploys microservices to Kubernetes cluster`
   - Check **"This project is parameterized"**
   - Click **"Add Parameter"** → **"Choice Parameter"**
     - Name: `SERVICE`
     - Choices (one per line):
       ```
       email-processor
       sqs-processor
       ```
     - Description: `Which microservice to deploy`
   - Click **"Add Parameter"** → **"String Parameter"**
     - Name: `IMAGE_TAG`
     - Default Value: `latest`
     - Description: `Docker image tag to deploy`
   - Click **"Add Parameter"** → **"Choice Parameter"**
     - Name: `ENVIRONMENT`
     - Choices (one per line):
       ```
       dev
       staging
       prod
       ```
     - Description: `Environment to deploy to`
   - Scroll to **Pipeline** section
   - **Definition**: Select **"Pipeline script from SCM"**
   - **SCM**: Select **"Git"**
   - **Repository URL**: `https://github.com/ramazulay/devops-project.git`
   - **Branch Specifier**: `*/main`
   - **Script Path**: `jenkins/Jenkinsfile-CD`
6. Click **Save**

**What this pipeline does:**
- Determines which service to deploy based on `SERVICE` parameter
- Pulls the specified Docker image from ECR
- Updates Kubernetes manifests with image tag
- Applies deployment to EKS cluster in the correct namespace
- Waits for rollout to complete
- Verifies pods are running
- Performs health check

---

## 🎯 Build & Deploy Applications

Now that pipelines are created, let's build and deploy both microservices!

### Step 1: Build Email Processor Image

1. Go to Jenkins dashboard
2. Click on **`microservices-ci`** pipeline
3. Click **"Build with Parameters"** (left sidebar)
4. Select **SERVICE**: `email-processor`
5. Click **"Build"**
6. Watch the build progress (click on build #1)
7. Click **"Console Output"** to see detailed logs

**What happens:**
- Code is checked out from Git
- Docker image is built from `microservice/` directory
- Image is pushed to ECR with tags `build-1` and `latest`
- Build takes ~3-5 minutes

**Success indicators:**
- Build status shows blue/green checkmark
- Console output shows: "Successfully pushed image"
- ECR has new image: `email-processor:build-1` and `email-processor:latest`

---

### Step 2: Deploy Email Processor to Kubernetes

1. Go to Jenkins dashboard
2. Click on **`microservices-cd`** pipeline
3. Click **"Build with Parameters"** (left sidebar)
4. Set parameters:
   - **SERVICE**: `email-processor`
   - **IMAGE_TAG**: `latest` (or `build-1`)
   - **ENVIRONMENT**: `dev`
5. Click **"Build"**
6. Watch deployment progress

**What happens:**
- Kubernetes namespace `email-processor` is created
- ConfigMap with environment variables is applied
- ServiceAccount with IAM role is created
- Deployment with your image is applied
- Service (LoadBalancer) is created
- Health checks verify application is running
- Deployment takes ~2-3 minutes

**Success indicators:**
- Build status shows blue/green checkmark
- Console output shows: "Deployment successful"
- Pods are running in `email-processor` namespace

---

### Step 3: Build SQS Processor Image

1. Go to Jenkins dashboard
2. Click on **`microservices-ci`** pipeline
3. Click **"Build with Parameters"**
4. Select **SERVICE**: `sqs-processor`
5. Click **"Build"**
6. Watch the build progress
7. Wait for completion (~3-5 minutes)

**Success indicators:**
- Build status shows blue/green checkmark
- ECR has new image: `sqs-processor:build-2` and `sqs-processor:latest`

---

### Step 4: Deploy SQS Processor to Kubernetes

1. Go to Jenkins dashboard
2. Click on **`microservices-cd`** pipeline
3. Click **"Build with Parameters"**
4. Set parameters:
   - **SERVICE**: `sqs-processor`
   - **IMAGE_TAG**: `latest` (or `build-2`)
   - **ENVIRONMENT**: `dev`
5. Click **"Build"**
6. Wait for deployment (~2-3 minutes)

**Success indicators:**
- Build status shows blue/green checkmark
- Pods are running in `sqs-processor` namespace

---

## ✅ Verify Deployments

### Check All Pods

```bash
# Check Email Processor
kubectl get pods -n email-processor

# Expected output:
# NAME                               READY   STATUS    RESTARTS   AGE
# email-processor-xxxxxxxxxx-xxxxx   1/1     Running   0          2m

# Check SQS Processor
kubectl get pods -n sqs-processor

# Expected output:
# NAME                              READY   STATUS    RESTARTS   AGE
# sqs-processor-xxxxxxxxxx-xxxxx    1/1     Running   0          2m
```

---

### Get Application URLs

```bash
# Get Email Processor URL
kubectl get svc -n email-processor

# Expected output shows LoadBalancer with EXTERNAL-IP
# Example: a1b2c3d4e5f6g7h8-123456789.us-west-1.elb.amazonaws.com
```

---

### Test Email Processor API

```bash
# Get the URL
EMAIL_PROCESSOR_URL=$(kubectl get svc email-processor -n email-processor -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test health endpoint
curl http://${EMAIL_PROCESSOR_URL}:8080/health

# Expected output: {"status":"healthy"}

# Send a test email
curl -X POST http://${EMAIL_PROCESSOR_URL}:8080/process \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "email_subject": "Test Email",
      "email_sender": "test@example.com",
      "email_timestream": "1693561101",
      "email_content": "This is a test message"
    },
    "token": "test-token-123"
  }'

# Expected output: {"status":"success","message":"Email data processed and queued"}
```

---

### Check SQS Messages Being Processed

```bash
# Load infrastructure outputs
source infrastructure-outputs.env

# Send a test message to SQS
aws sqs send-message \
    --queue-url ${SQS_QUEUE_URL} \
    --message-body '{"test":"message","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' \
    --region ${AWS_REGION}

# Wait 30 seconds for SQS processor to pick it up
sleep 30

# Check S3 for processed messages
aws s3 ls s3://${S3_BUCKET}/sqs-messages/ --recursive

# You should see files like:
# sqs-messages/2025/11/28/14/msg-abc123.json
```

---

### View Application Logs

```bash
# Email Processor logs
kubectl logs -n email-processor -l app=email-processor -f

# SQS Processor logs
kubectl logs -n sqs-processor -l app=sqs-processor -f

# Press Ctrl+C to stop following logs
```
---

## 🧹 Cleanup

```bash
# Delete applications
kubectl delete namespace email-processor
kubectl delete namespace sqs-processor
kubectl delete namespace jenkins

```
**Note**: Delete Load Balancers first:
```bash
# List and delete load balancers
aws elb describe-load-balancers --region us-west-1
aws elb delete-load-balancer --load-balancer-name <lb-name> --region us-west-1

# Delete infrastructure
cd enviroments/dev
tofu destroy -var-file=terraform.tfvars
```

---

## 📚 What Gets Deployed

**Infrastructure**:
- VPC with public/private subnets
- EKS Cluster (Kubernetes v1.32)
- ECR, SQS, S3, IAM roles

**Applications**:
- **Email Processor**: HTTP API that sends messages to SQS
- **SQS Processor**: Background worker that saves messages to S3

