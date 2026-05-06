# 🔒 DevSecOps CI/CD Pipeline — Hotstar Clone on AWS EKS

> Secure, automated CI/CD pipeline using Jenkins, SonarQube, OWASP ZAP, Docker Scout, Trivy, and Terraform on AWS EKS.

## Pipeline Overview

```
GitHub Push → Jenkins → SonarQube SAST → Quality Gate → OWASP Dependency Check
→ Docker Build → Docker Scout FS Scan → Trivy Image Scan → Push to ECR
→ Deploy to EKS → OWASP ZAP DAST → Smoke Test ✓
```

## Project Structure

```
.
├── Dockerfile                          # Multi-stage, non-root, hardened
├── Jenkinsfile                         # Full 14-stage DevSecOps pipeline
├── nginx.conf                          # Security headers, SPA routing
├── sonar-project.properties            # SonarQube config
├── terraform/
│   ├── environments/prod/              # Environment-specific TF config
│   │   ├── main.tf                     # VPC + EKS + ECR orchestration
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── modules/
│       ├── vpc/                        # VPC, subnets, NAT gateways
│       ├── eks/                        # EKS cluster + node groups + IAM
│       └── security-groups/            # Jenkins + EKS security groups
├── k8s/
│   ├── deployment.yaml                 # Deployment with security contexts
│   ├── service.yaml                    # AWS LoadBalancer service
│   ├── hpa.yaml                        # Horizontal Pod Autoscaler
│   └── network-policy.yaml             # Network isolation
├── scripts/
│   └── install-jenkins.sh              # One-shot tool installation script
└── docs/
    └── DEPLOY-GUIDE.html               # Step-by-step deployment guide
```

## Quick Start

1. **AWS Setup** — Create IAM user, S3 state bucket, DynamoDB lock table
2. **Launch EC2** — t2.large Ubuntu 22.04, run `scripts/install-jenkins.sh`
3. **Terraform** — `cd terraform/environments/prod && terraform init && terraform apply`
4. **SonarQube** — Create project, generate token, configure webhook
5. **Jenkins** — Install plugins, add credentials, create pipeline job
6. **Push code** — Pipeline triggers automatically!

## Security Layers

| Layer | Tool | What It Catches |
|-------|------|-----------------|
| SAST | SonarQube | Code bugs, vulnerabilities, code smells |
| SCA | OWASP Dependency Check | CVEs in npm dependencies |
| Container FS | Docker Scout | Filesystem vulnerabilities before build |
| Container Image | Docker Scout + Trivy | Image CVEs, misconfigurations |
| DAST | OWASP ZAP | Runtime web app vulnerabilities |
| Registry | AWS ECR | Auto-scan images on push |

## Source Reference

Based on: https://github.com/DevOpsInstituteMumbai-wq/Implementing-a-Secure-CI-CD-Pipeline-for-Hotstar-Clone-Using-DevSecOps-Principles
