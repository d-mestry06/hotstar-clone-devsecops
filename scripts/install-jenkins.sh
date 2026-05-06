#!/usr/bin/env bash
set -euo pipefail

log() { echo -e "\n\033[1;34m[$(date '+%H:%M:%S')] $*\033[0m"; }

export DEBIAN_FRONTEND=noninteractive
CODENAME=$(lsb_release -cs)

# ── SYSTEM UPDATE ────────────────────────────────────────────
log "Updating system..."
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y \
  curl wget gnupg ca-certificates lsb-release \
  apt-transport-https software-properties-common \
  unzip jq git fontconfig

# ── JAVA 21 ─────────────────────────────────────────────────
log "Installing Java 21..."
sudo apt-get install -y openjdk-21-jre
java -version

# ── JENKINS (LATEST FIXED METHOD) ────────────────────────────
log "Installing Jenkins..."

sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/jenkins.gpg

sudo chmod 644 /etc/apt/keyrings/jenkins.gpg

echo "deb [signed-by=/etc/apt/keyrings/jenkins.gpg] \
https://pkg.jenkins.io/debian-stable binary/" | \
sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y jenkins

sudo systemctl daemon-reexec
sudo systemctl enable jenkins
sudo systemctl start jenkins

# ── DOCKER (LATEST METHOD) ───────────────────────────────────
log "Installing Docker..."

sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

sudo chmod 644 /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu ${CODENAME} stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

sudo systemctl enable docker
sudo systemctl start docker

sudo usermod -aG docker ubuntu
sudo usermod -aG docker jenkins

# ── TRIVY ────────────────────────────────────────────────────
log "Installing Trivy..."

curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | \
  sudo sh -s -- -b /usr/local/bin

trivy --version

# ── AWS CLI v2 ───────────────────────────────────────────────
log "Installing AWS CLI..."

curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws

aws --version

# ── kubectl (LATEST STABLE) ──────────────────────────────────
log "Installing kubectl..."

KUBECTL_VERSION=$(curl -s https://dl.k8s.io/release/stable.txt)

curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl
sudo install -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

kubectl version --client

# ── Terraform (LATEST) ───────────────────────────────────────
log "Installing Terraform..."

curl -fsSL https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg

sudo chmod 644 /usr/share/keyrings/hashicorp.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] \
https://apt.releases.hashicorp.com ${CODENAME} main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y terraform

terraform version

# ── Node.js (LTS) ────────────────────────────────────────────
log "Installing Node.js..."

curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

node -v
npm -v

# ── SonarQube (Docker) ───────────────────────────────────────
log "Starting SonarQube..."

sudo docker run -d \
  --name sonarqube \
  --restart unless-stopped \
  -p 9000:9000 \
  -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
  sonarqube:10.5.1-community
# ── FINAL OUTPUT ─────────────────────────────────────────────
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

log "===================================================="
log "🚀 DEVSECOPS SETUP COMPLETE"
log "===================================================="

echo "Jenkins   → http://${PUBLIC_IP}:8080"
echo "SonarQube → http://${PUBLIC_IP}:9000 (admin/admin)"
echo ""

echo "Jenkins Initial Password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

echo ""
echo "IMPORTANT:"
echo "- Open port 8080 (Jenkins)"
echo "- Open port 9000 (SonarQube)"
echo "- Run: newgrp docker (or logout/login)"
echo "- Restart Jenkins after Docker access:"
echo "  sudo systemctl restart jenkins"