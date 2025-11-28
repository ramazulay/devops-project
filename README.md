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
   - **Repository URL**: Enter your Git repository URL
     - Example: `https://github.com/yourusername/devops-project.git`
   - **Credentials**: If private repo, add Git credentials (click "Add")
   - **Branch Specifier**: `*/main` (or your branch name)
   - **Script Path**: `Jenkinsfile-CI` (we'll create a unified CI Jenkinsfile)
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
   - **Repository URL**: Your Git repository URL
   - **Branch Specifier**: `*/main`
   - **Script Path**: `Jenkinsfile-CD` (we'll create a unified CD Jenkinsfile)
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

### Alternative: Separate Pipelines (If You Prefer)

If you prefer having separate pipelines for each service for clarity, you can create 4 pipelines:

- `email-processor-ci` → Script Path: `microservice/Jenkinsfile-CI`
- `email-processor-cd` → Script Path: `microservice/Jenkinsfile-CD`
- `sqs-processor-ci` → Script Path: `sqs-processor/Jenkinsfile-CI`
- `sqs-processor-cd` → Script Path: `sqs-processor/Jenkinsfile-CD`

**Benefits of unified approach:**
- ✅ Less pipelines to manage (2 vs 4)
- ✅ Consistent build/deploy process
- ✅ Easier to add new microservices

**Benefits of separate approach:**
- ✅ Clearer which service is being built/deployed
- ✅ Simpler Jenkinsfiles (no parameter logic)
- ✅ Separate build history per service

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

### Quick Build & Deploy (Both Services)

To deploy both services quickly:

```bash
# Option 1: Use Jenkins (2 pipelines, 4 builds total)
# Build both images
1. microservices-ci → SERVICE: email-processor → Build
2. microservices-ci → SERVICE: sqs-processor → Build

# Deploy both services
3. microservices-cd → SERVICE: email-processor, IMAGE_TAG: latest, ENV: dev → Build
4. microservices-cd → SERVICE: sqs-processor, IMAGE_TAG: latest, ENV: dev → Build
```

**OR if using separate pipelines:**

```bash
# Build images
1. email-processor-ci → Build Now
2. sqs-processor-ci → Build Now

# Deploy services
3. email-processor-cd → Build with Parameters (IMAGE_TAG: latest, ENV: dev)
4. sqs-processor-cd → Build with Parameters (IMAGE_TAG: latest, ENV: dev)
```

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

## 🔄 Understanding CI/CD Workflow

### CI Pipeline (Continuous Integration)

**Triggers**: Manual build (or can be automated with Git webhooks)

**Steps:**
1. **Checkout**: Clone repository
2. **Build**: Create Docker image from Dockerfile
3. **Test**: Run unit tests (if configured)
4. **Tag**: Tag image with build number
5. **Push**: Upload image to AWS ECR

**Output**: Docker image in ECR (e.g., `email-processor:build-5`)

---

### CD Pipeline (Continuous Deployment)

**Triggers**: Manual with parameters

**Steps:**
1. **Checkout**: Clone repository
2. **Configure**: Set up kubectl for EKS
3. **Verify**: Check image exists in ECR
4. **Update**: Modify K8s manifests with image tag
5. **Deploy**: Apply manifests to cluster
6. **Wait**: Monitor rollout progress
7. **Verify**: Check pods are healthy
8. **Test**: Perform health check

**Output**: Running application in Kubernetes

---

## 🔁 Making Changes & Redeploying

### Scenario: You updated the Email Processor code

1. **Commit changes** to Git repository
2. Go to Jenkins → **`microservices-ci`**
3. Click **"Build with Parameters"**
4. Select **SERVICE**: `email-processor`
5. Click **"Build"** (creates build-3)
6. Wait for build to complete
7. Go to **`microservices-cd`**
8. Click **"Build with Parameters"**
9. Select **SERVICE**: `email-processor`
10. Set **IMAGE_TAG**: `build-3` (or `latest`)
11. Set **ENVIRONMENT**: `dev`
12. Click **"Build"**
13. New version is deployed!

### Rolling Back to Previous Version

1. Go to **`microservices-cd`**
2. Click **"Build with Parameters"**
3. Select **SERVICE**: `email-processor`
4. Set **IMAGE_TAG**: `build-2` (previous version)
5. Set **ENVIRONMENT**: `dev`
6. Click **"Build"**
7. Application rolls back to previous version

---

## 📝 Pipeline Summary

### Unified Approach (Recommended)

| Pipeline | What It Does | Parameters |
|----------|--------------|------------|
| **microservices-ci** | Builds and pushes Docker images to ECR | SERVICE (email-processor, sqs-processor) |
| **microservices-cd** | Deploys microservices to Kubernetes | SERVICE, IMAGE_TAG, ENVIRONMENT |

**Total**: 2 pipelines for all microservices

### Separate Approach (Alternative)

| Pipeline | What It Does | Parameters |
|----------|--------------|------------|
| **email-processor-ci** | Builds Email Processor image | None |
| **email-processor-cd** | Deploys Email Processor | IMAGE_TAG, ENVIRONMENT |
| **sqs-processor-ci** | Builds SQS Processor image | None |
| **sqs-processor-cd** | Deploys SQS Processor | IMAGE_TAG, ENVIRONMENT |

**Total**: 4 pipelines (2 per microservice)

---

## 🧹 Cleanup

```bash
# Delete applications
kubectl delete namespace email-processor
kubectl delete namespace sqs-processor
kubectl delete namespace jenkins

# Delete infrastructure
cd enviroments/dev
tofu destroy -var-file=terraform.tfvars
```

**Note**: If you get subnet deletion errors, delete Load Balancers first:
```bash
# List and delete load balancers
aws elb describe-load-balancers --region us-west-1
aws elb delete-load-balancer --load-balancer-name <lb-name> --region us-west-1

# Wait 30 seconds, then retry destroy
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

---

**Cost**: ~$150-200/month  
**Support**: Check logs with `kubectl logs` or review Jenkins console output
