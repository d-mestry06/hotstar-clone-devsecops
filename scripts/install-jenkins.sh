#!/usr/bin/env bash
# ============================================================
# Jenkins + Tools Installation Script for Ubuntu 22.04 / EC2
# ============================================================
set -euo pipefail

log() { echo -e "\n\033[1;34m[$(date '+%H:%M:%S')] $*\033[0m"; }
err() { echo -e "\033[1;31m[ERROR] $*\033[0m" >&2; exit 1; }

# ── System Update ────────────────────────────────────────────
log "Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y curl wget gnupg2 ca-certificates lsb-release apt-transport-https \
    software-properties-common unzip jq git

# ── Java 17 ─────────────────────────────────────────────────
log "Installing Java 17..."
sudo apt-get install -y openjdk-17-jdk
java -version

# ── Jenkins ─────────────────────────────────────────────────
log "Installing Jenkins..."
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
    sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/ | \
    sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins
log "Jenkins installed. Initial admin password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# ── Docker ───────────────────────────────────────────────────
log "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable docker
sudo usermod -aG docker jenkins
sudo usermod -aG docker ubuntu
log "Docker installed: $(docker --version)"

# ── Docker Scout ─────────────────────────────────────────────
log "Installing Docker Scout..."
curl -sSfL https://raw.githubusercontent.com/docker/scout-cli/main/install.sh | sh -s --
log "Docker Scout installed"

# ── Trivy ────────────────────────────────────────────────────
log "Installing Trivy..."
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | \
    sudo sh -s -- -b /usr/local/bin
log "Trivy installed: $(trivy --version)"

# ── AWS CLI ──────────────────────────────────────────────────
log "Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws/
log "AWS CLI installed: $(aws --version)"

# ── kubectl ──────────────────────────────────────────────────
log "Installing kubectl..."
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
log "kubectl installed: $(kubectl version --client --short)"

# ── Terraform ────────────────────────────────────────────────
log "Installing Terraform..."
wget -O- https://apt.releases.hashicorp.com/gpg | \
    sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update -y && sudo apt-get install -y terraform
log "Terraform installed: $(terraform version)"

# ── SonarQube (Docker) ───────────────────────────────────────
log "Starting SonarQube via Docker..."
sudo docker run -d \
    --name sonarqube \
    --restart unless-stopped \
    -p 9000:9000 \
    -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
    -v sonarqube_data:/opt/sonarqube/data \
    -v sonarqube_logs:/opt/sonarqube/logs \
    -v sonarqube_extensions:/opt/sonarqube/extensions \
    sonarqube:10-community
log "SonarQube starting at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000"

# ── SonarQube Scanner ────────────────────────────────────────
log "Installing SonarQube Scanner..."
SONAR_SCANNER_VERSION="5.0.1.3006"
wget -q "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux.zip"
unzip -q "sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux.zip"
sudo mv "sonar-scanner-${SONAR_SCANNER_VERSION}-linux" /opt/sonar-scanner
sudo ln -sf /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner
rm "sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux.zip"
log "SonarQube Scanner installed"

# ── Node.js ──────────────────────────────────────────────────
log "Installing Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
log "Node.js: $(node --version) | npm: $(npm --version)"

# ── Final Summary ────────────────────────────────────────────
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
log "============================================================"
log " INSTALLATION COMPLETE!"
log "============================================================"
echo "  Jenkins   → http://${PUBLIC_IP}:8080"
echo "  SonarQube → http://${PUBLIC_IP}:9000  (admin/admin)"
echo ""
echo "  Jenkins initial password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
echo ""
echo "  NOTE: Restart Jenkins to pick up Docker group:"
echo "  sudo systemctl restart jenkins"
