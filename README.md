# 🔒 DevSecOps CI/CD Pipeline — Hotstar Clone on AWS EKS

> Secure, automated CI/CD deployment of a React Hotstar Clone app on AWS EKS using Jenkins, Terraform, Docker, Kubernetes, and monitoring tools.

## Pipeline Overview

This project runs a 15-stage DevSecOps pipeline:

```
GitHub Push → Jenkins
→ Install dependencies
→ SonarQube SAST → Quality Gate
→ NPM Audit → OWASP Dependency Check
→ Docker Build → Trivy FS Scan
→ Docker Scout Analysis → Trivy Image Scan
→ Push to ECR → Deploy to EKS
→ Setup Monitoring (Prometheus + Grafana + AlertManager)
→ OWASP ZAP DAST → Smoke Test ✓
```

## Project Structure

```
.
├── Dockerfile                          # Multi-stage container image for the React app
├── Jenkinsfile                         # 15-stage DevSecOps CI/CD pipeline
├── nginx.conf                          # Nginx config and SPA routing
├── sonar-project.properties            # SonarQube configuration
├── monitoring/
│   ├── prometheus-values.yaml          # kube-prometheus-stack values
│   ├── alert-rules.yaml                # Prometheus alert rules
│   └── servicemonitor.yaml             # Custom ServiceMonitor for app metrics
├── k8s/
│   ├── deployment.yaml                 # Kubernetes Deployment with security contexts
│   ├── service.yaml                    # AWS NLB/LoadBalancer service
│   ├── hpa.yaml                        # Horizontal Pod Autoscaler
│   └── network-policy.yaml             # Namespace/network policy rules
├── terraform/
│   ├── environments/prod/              # Terraform environment config
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── modules/
│       ├── eks/
│       └── vpc/                        # VPC, subnets, NAT, security groups
├── scripts/
│   └── install-jenkins.sh              # Jenkins EC2 setup script
└── jenkins/                            # Jenkins-related resources and configs
```

## Quick Start

1. **Prepare AWS resources** — create IAM user, S3 bucket for Terraform state, and DynamoDB lock table.
2. **Provision infrastructure** — run Terraform in `terraform/environments/prod`.
3. **Launch EC2 for Jenkins** — use the Terraform-created security group and run `scripts/install-jenkins.sh`.
4. **Configure tools** — set up SonarQube, Jenkins credentials, AWS credentials, and Slack/Grafana secrets.
5. **Deploy** — push code to GitHub and let Jenkins run the full pipeline.
6. **Monitor** — access Prometheus and Grafana from the EKS monitoring stack.

## Security Layers

| Layer | Tool | What It Catches |
|-------|------|-----------------|
| SAST | SonarQube | Code bugs, vulnerabilities, code smells |
| SCA | OWASP Dependency Check | CVEs in npm dependencies |
| Container FS | Docker Scout | Filesystem vulnerabilities before build |
| Container Image | Docker Scout + Trivy | Image CVEs and container misconfigurations |
| DAST | OWASP ZAP | Runtime web app vulnerabilities |
| Registry | AWS ECR | Secure image storage and deployment |
| Monitoring | Prometheus + Grafana + AlertManager | Cluster health, app metrics, alerts |

## Source Reference

Based on: https://github.com/DevOpsInstituteMumbai-wq/Implementing-a-Secure-CI-CD-Pipeline-for-Hotstar-Clone-Using-DevSecOps-Principles
kjjjjjkkjkj
test pipeline