# Deployment Approach

## 📋 Overview

This project follows a **two-phase deployment approach**:

1. **Infrastructure Deployment** - Automated via shell script
2. **Application Deployment** - Managed via Jenkins CI/CD pipelines

---

## 🏗️ Phase 1: Infrastructure Deployment (Automated)

### Script: `deploy-infra.sh`

This script automates the deployment of all infrastructure components:

- ✅ AWS VPC with public/private subnets
- ✅ EKS Cluster (Kubernetes v1.32)
- ✅ ECR Container Registry
- ✅ SQS Queue + Dead Letter Queue
- ✅ S3 Bucket with versioning
- ✅ IAM Roles and Policies
- ✅ EBS CSI Driver for persistent storage

**Usage:**
```bash
./GET_STARTED.sh       # Check prerequisites
./deploy-infra.sh      # Deploy infrastructure
```

**Duration**: ~15-20 minutes

---

### Jenkins Deployment: `jenkins/deploy-jenkins.sh`

After infrastructure is ready, deploy Jenkins CI/CD server:

**What it does:**
- ✅ Creates Jenkins namespace in Kubernetes
- ✅ Deploys Jenkins with persistent storage (20Gi PVC)
- ✅ Creates LoadBalancer for external access
- ✅ Sets up IRSA (IAM role) for AWS permissions
- ✅ Enables Docker-in-Docker for building images

**Usage:**
```bash
cd jenkins
./deploy-jenkins.sh    # Deploy Jenkins on EKS
```

**Duration**: ~5 minutes

**Verification:**
```bash
# Check Jenkins pod
kubectl get pods -n jenkins

# Get Jenkins URL
kubectl get svc jenkins -n jenkins

# Get admin password
kubectl exec -n jenkins $(kubectl get pods -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -- cat /var/jenkins_home/secrets/initialAdminPassword
```

---

## 🚀 Phase 2: Application Deployment (Via Jenkins)

### Applications:
1. **Email Processor** - HTTP API microservice
2. **SQS Processor** - Background worker microservice

### Why Jenkins CI/CD (not scripted)?

#### 1. **Version Control & Git Integration**
- Jenkins pulls code directly from Git repositories
- Triggers builds on code commits (webhooks)
- Maintains build history and artifacts

#### 2. **Multi-Stage Pipelines**
- **CI Pipeline (Jenkinsfile-CI)**:
  - Code checkout
  - Docker image build
  - Push to ECR
  - Image scanning
  - Unit tests

- **CD Pipeline (Jenkinsfile-CD)**:
  - Pull image from ECR
  - Update Kubernetes manifests
  - Deploy to EKS
  - Health checks
  - Rollback capability

#### 3. **Environment Management**
- Different pipelines for dev/staging/prod
- Environment-specific configurations
- Approval gates for production

#### 4. **Audit Trail**
- Every deployment is logged
- Who deployed what, when
- Build console outputs saved
- Compliance and governance

#### 5. **Team Collaboration**
- Multiple team members can trigger deployments
- Role-based access control (RBAC)
- Notifications (Slack, email) on build status

#### 6. **Best Practices**
- Industry-standard CI/CD approach
- Separation of concerns (infra vs apps)
- Easier troubleshooting
- Better for production environments

---

## 🔄 Deployment Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                     DEPLOYMENT WORKFLOW                       │
└─────────────────────────────────────────────────────────────┘

1. INFRASTRUCTURE (Automated Script)
   ┌──────────────────────┐
   │  ./GET_STARTED.sh    │  ← Check prerequisites
   └──────────┬───────────┘
              │
   ┌──────────▼───────────┐
   │  ./deploy-infra.sh   │  ← Deploy AWS resources
   └──────────┬───────────┘
              │
   ┌──────────▼───────────┐
   │   EKS + Jenkins      │  ← Infrastructure ready
   │   ECR + SQS + S3     │
   └──────────┬───────────┘
              │
              │
2. APPLICATION DEPLOYMENT (Via Jenkins)
   ┌──────────▼───────────┐
   │  Access Jenkins      │  ← Get LoadBalancer URL
   │  Configure Creds     │
   └──────────┬───────────┘
              │
   ┌──────────▼───────────┐
   │  Create CI Pipeline  │  ← Build & push images
   │  Create CD Pipeline  │  ← Deploy to Kubernetes
   └──────────┬───────────┘
              │
   ┌──────────▼───────────┐
   │  Microservices       │  ← Applications running
   │  Email Processor     │
   │  SQS Processor       │
   └──────────────────────┘
```

---

## 📁 File Structure

```
devops-project/
├── GET_STARTED.sh           # Prerequisite checker
├── deploy-infra.sh          # Infrastructure deployment
│
├── enviroments/dev/         # Terraform configs
│   ├── main.tf
│   ├── variables.tf
│   └── terraform.tfvars
│
├── microservice/            # Email Processor
│   ├── Jenkinsfile-CI       # Build pipeline
│   ├── Jenkinsfile-CD       # Deploy pipeline
│   ├── Dockerfile
│   └── k8s/                 # Kubernetes manifests
│
└── sqs-processor/           # SQS Processor
    ├── Jenkinsfile-CI       # Build pipeline
    ├── Jenkinsfile-CD       # Deploy pipeline
    ├── Dockerfile
    └── k8s/                 # Kubernetes manifests
```

---

## 🔐 Security Considerations

### Infrastructure Script (`deploy-infra.sh`)
- ✅ Runs with user's AWS credentials
- ✅ IAM roles created with least privilege
- ✅ Encryption at rest for S3 and EBS
- ✅ Private subnets for workloads
- ✅ IRSA (IAM Roles for Service Accounts) configured

### Jenkins Pipelines
- ✅ Credentials stored securely in Jenkins
- ✅ Docker images scanned for vulnerabilities
- ✅ Kubernetes manifests validated
- ✅ RBAC enforced in Kubernetes
- ✅ Secrets managed via Kubernetes Secrets/ConfigMaps

---

## 🎯 Summary

| Aspect | Infrastructure | Applications |
|--------|---------------|--------------|
| **Tool** | Shell script + Terraform | Jenkins CI/CD |
| **When** | Once (or infrastructure changes) | Every code change |
| **Who** | DevOps/Platform team | Developers + DevOps |
| **How** | `./deploy-infra.sh` | Jenkins pipelines |
| **Why** | One-time setup, stable | Frequent updates, iterative |

---

## 📚 Next Steps

1. **Deploy Infrastructure**: `./deploy-infra.sh`
2. **Access Jenkins**: Get URL from `kubectl get svc -n jenkins`
3. **Configure Jenkins**: Follow [README.md](README.md#jenkins-configuration)
4. **Set up Pipelines**: Follow [README.md](README.md#cicd-pipeline-setup)
5. **Deploy Apps**: Trigger Jenkins jobs

---

## ❓ FAQ

### Q: Why not deploy apps with a script too?
**A:** Jenkins provides version control integration, automated triggers, multi-stage pipelines, audit trails, and is industry-standard for production CI/CD.

### Q: Can I still deploy apps manually without Jenkins?
**A:** Yes! Each microservice has a `deploy.sh` script for manual deployment. But Jenkins is recommended for production.

### Q: What if I want to deploy apps automatically without Jenkins?
**A:** You could use:
- GitHub Actions / GitLab CI
- ArgoCD (GitOps approach)
- FluxCD (GitOps approach)
- AWS CodePipeline

### Q: Why is Jenkins deployed in the infrastructure script?
**A:** Jenkins is part of the platform infrastructure. It's deployed once and used continuously for app deployments.

---

**Last Updated**: November 28, 2025  
**Status**: ✅ Production Approach
