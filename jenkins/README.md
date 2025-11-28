# Jenkins CI/CD Setup for Email Processor Microservice

## 📋 Overview

This directory contains everything needed to set up Jenkins on Kubernetes with CI/CD pipelines for the email processor microservice.

### Components

- **Jenkins Server**: Running on Kubernetes with Docker-in-Docker (DinD)
- **CI Pipeline**: Builds Docker image and pushes to ECR
- **CD Pipeline**: Deploys the image to EKS

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Jenkins on EKS                           │
│                                                              │
│  ┌──────────────┐         ┌──────────────┐                 │
│  │              │         │              │                  │
│  │  CI Pipeline │────────▶│ CD Pipeline  │                  │
│  │              │         │              │                  │
│  └──────┬───────┘         └──────┬───────┘                  │
│         │                        │                          │
└─────────┼────────────────────────┼──────────────────────────┘
          │                        │
          ▼                        ▼
   ┌─────────────┐          ┌──────────────┐
   │     ECR     │          │  EKS Cluster │
   │ (Registry)  │          │  (Workloads) │
   └─────────────┘          └──────────────┘
```

## 📁 Directory Structure

```
jenkins/
├── k8s/                           # Kubernetes manifests
│   ├── namespace.yaml             # Jenkins namespace
│   ├── serviceaccount.yaml        # Service account with IRSA
│   ├── configmap.yaml             # Configuration
│   ├── pvc.yaml                   # Persistent storage
│   └── deployment.yaml            # Jenkins deployment + service
├── Jenkinsfile-CI                 # CI pipeline definition
├── Jenkinsfile-CD                 # CD pipeline definition
├── jenkins-iam-policy.json        # IAM policy for Jenkins
├── deploy-jenkins.sh              # Deployment script
└── README.md                      # This file
```

## 🚀 Quick Start

### Prerequisites

1. EKS cluster running
2. kubectl configured
3. AWS CLI configured
4. Terraform infrastructure deployed

### Deploy Jenkins

```bash
cd jenkins
chmod +x deploy-jenkins.sh
./deploy-jenkins.sh
```

This script will:
1. Create IAM role for Jenkins (IRSA)
2. Deploy Jenkins to Kubernetes
3. Set up persistent storage
4. Create LoadBalancer service
5. Display Jenkins URL and initial password

### Access Jenkins

1. Get Jenkins URL:
```bash
kubectl get svc jenkins -n jenkins
```

2. Get initial admin password:
```bash
POD_NAME=$(kubectl get pods -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n jenkins $POD_NAME -- cat /var/jenkins_home/secrets/initialAdminPassword
```

3. Open Jenkins in browser and complete setup wizard

## 🔧 Configure Jenkins

### Install Required Plugins

After initial setup, install these plugins:
- Docker Pipeline
- Kubernetes
- AWS Steps
- Git
- Pipeline
- Blue Ocean (optional)

### Configure Credentials

1. **AWS Credentials** (use IRSA - already configured)
2. **Git Credentials** (if using private repo)

### Set Environment Variables

In Jenkins → Manage Jenkins → Configure System:

- `AWS_REGION`: `us-west-1`
- `ECR_REGISTRY`: `<AWS_ACCOUNT_ID>.dkr.ecr.us-west-1.amazonaws.com`
- `ECR_REPOSITORY`: `my-app-repo`
- `EKS_CLUSTER`: `dev-CP-EKS-CLUSTER`

## 📝 Create CI Pipeline

1. Click "New Item"
2. Enter name: `email-processor-ci`
3. Select "Pipeline"
4. Under Pipeline section:
   - Definition: Pipeline script from SCM
   - SCM: Git
   - Repository URL: Your git repository
   - Script Path: `jenkins/Jenkinsfile-CI`
5. Save

### CI Pipeline Stages

1. **Checkout**: Clone repository
2. **Build Docker Image**: Build from Dockerfile
3. **Run Tests**: Execute unit tests
4. **Login to ECR**: Authenticate with ECR
5. **Push to ECR**: Push image with build number tag
6. **Archive Artifacts**: Save image version

### Test CI Pipeline

Click "Build Now" - The pipeline will:
- Build the Docker image
- Run tests
- Push to ECR as `my-app-repo:BUILD_NUMBER` and `my-app-repo:latest`

## 📝 Create CD Pipeline

1. Click "New Item"
2. Enter name: `email-processor-cd`
3. Select "Pipeline"
4. Check "This project is parameterized"
5. Add parameters:
   - String: `IMAGE_TAG` (default: `latest`)
   - Choice: `ENVIRONMENT` (choices: `dev`, `staging`, `prod`)
6. Under Pipeline section:
   - Definition: Pipeline script from SCM
   - SCM: Git
   - Repository URL: Your git repository
   - Script Path: `jenkins/Jenkinsfile-CD`
7. Save

### CD Pipeline Stages

1. **Checkout**: Clone repository
2. **Configure kubectl**: Set up EKS access
3. **Verify Image**: Check image exists in ECR
4. **Update Manifests**: Update deployment with new image
5. **Deploy to Kubernetes**: Apply manifests
6. **Wait for Rollout**: Wait for deployment completion
7. **Verify Deployment**: Check pod status
8. **Health Check**: Test application health

### Test CD Pipeline

Click "Build with Parameters":
- IMAGE_TAG: `latest` or specific build number
- ENVIRONMENT: `dev`

The pipeline will deploy to EKS!

## 🔄 Complete CI/CD Flow

### Automated Flow

1. **Trigger CI Pipeline** (manually or via webhook)
2. CI builds image and pushes to ECR with build number
3. **Trigger CD Pipeline** manually with IMAGE_TAG from CI
4. CD deploys the specific image version to EKS

### Setting Up Automated Trigger

Add to CI Pipeline (post-success):
```groovy
build job: 'email-processor-cd', 
    parameters: [
        string(name: 'IMAGE_TAG', value: env.BUILD_NUMBER),
        string(name: 'ENVIRONMENT', value: 'dev')
    ]
```

## 🔒 IAM Permissions

Jenkins requires these permissions:

### ECR Access
- `ecr:GetAuthorizationToken`
- `ecr:BatchCheckLayerAvailability`
- `ecr:PutImage`
- `ecr:InitiateLayerUpload`
- `ecr:UploadLayerPart`
- `ecr:CompleteLayerUpload`
- `ecr:DescribeImages`

### EKS Access
- `eks:DescribeCluster`
- `eks:ListClusters`

### Kubernetes RBAC
- Create/update/delete pods, deployments, services
- Get/list resources in all namespaces
- Exec into pods

## 📊 Monitoring Jenkins

### View Logs
```bash
kubectl logs -f -n jenkins deployment/jenkins
```

### Check Status
```bash
kubectl get all -n jenkins
```

### Access Jenkins Pod
```bash
POD_NAME=$(kubectl get pods -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it -n jenkins $POD_NAME -- /bin/bash
```

## 🔧 Troubleshooting

### Jenkins Not Starting
```bash
kubectl describe pod -n jenkins
kubectl logs -n jenkins <pod-name>
```

### ECR Push Fails
- Check IAM role has ECR permissions
- Verify ECR repository exists
- Check AWS region is correct

### Deployment Fails
- Verify kubectl is configured
- Check service account has correct permissions
- Verify image exists in ECR

### Docker Build Fails
- Check Dockerfile syntax
- Verify all dependencies are available
- Check DinD container is running

## 🎯 Best Practices

1. **Use Specific Image Tags**: Don't rely only on `latest`
2. **Test Before Deploy**: Run tests in CI pipeline
3. **Rollback Strategy**: Keep previous image versions
4. **Monitor Deployments**: Check pod logs after deploy
5. **Use Branches**: Different pipelines for dev/staging/prod
6. **Backup Jenkins**: Regular backups of Jenkins home

## 📈 Scaling Jenkins

### Add More Executors
Edit deployment and increase replicas (requires shared storage configuration)

### Use Jenkins Agents
Configure Kubernetes plugin to spawn dynamic agents

### Resource Limits
Adjust CPU/Memory in deployment.yaml based on workload

## 🔄 Updating Jenkins

```bash
kubectl set image deployment/jenkins jenkins=jenkins/jenkins:lts-jdk17 -n jenkins
kubectl rollout status deployment/jenkins -n jenkins
```

## 🗑️ Cleanup

Remove Jenkins:
```bash
kubectl delete namespace jenkins
```

Remove IAM resources:
```bash
aws iam detach-role-policy --role-name jenkins-role --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/JenkinsECRAndEKSPolicy
aws iam delete-role --role-name jenkins-role
aws iam delete-policy --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/JenkinsECRAndEKSPolicy
```

## 📚 Additional Resources

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Jenkins Kubernetes Plugin](https://plugins.jenkins.io/kubernetes/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

---

**Happy CI/CD! 🚀**
