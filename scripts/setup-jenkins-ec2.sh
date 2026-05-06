#!/bin/bash
# =============================================================================
# jenkins/setup-jenkins-ec2.sh
# Installs Jenkins + Docker + kubectl + Terraform + AWS CLI on Ubuntu 22.04
# Run as: sudo bash setup-jenkins-ec2.sh
# =============================================================================
set -euo pipefail

echo "════════════════════════════════════════════════════════"
echo "  DevSecOps Jenkins Setup – Ubuntu 22.04"
echo "════════════════════════════════════════════════════════"

# ── 0. System update ──────────────────────────────────────────────────────────
apt-get update -y && apt-get upgrade -y
apt-get install -y curl wget git unzip jq gnupg lsb-release ca-certificates apt-transport-https

# ── 1. Java 17 (required for Jenkins) ────────────────────────────────────────
echo "▶ Installing Java 17..."
apt-get install -y openjdk-17-jdk
java -version

# ── 2. Jenkins LTS ───────────────────────────────────────────────────────────
echo "▶ Installing Jenkins..."
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
  tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" | \
  tee /etc/apt/sources.list.d/jenkins.list > /dev/null
apt-get update -y
apt-get install -y jenkins
systemctl enable jenkins
systemctl start jenkins

# ── 3. Docker ─────────────────────────────────────────────────────────────────
echo "▶ Installing Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin

# Add jenkins user to docker group
usermod -aG docker jenkins
systemctl enable docker
systemctl start docker

# ── 4. Docker Scout CLI ───────────────────────────────────────────────────────
echo "▶ Installing Docker Scout..."
curl -fsSL https://raw.githubusercontent.com/docker/scout-cli/main/install.sh | sh -s --

# ── 5. AWS CLI v2 ─────────────────────────────────────────────────────────────
echo "▶ Installing AWS CLI..."
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
aws --version

# ── 6. kubectl ────────────────────────────────────────────────────────────────
echo "▶ Installing kubectl..."
KUBECTL_VERSION=$(curl -Ls https://dl.k8s.io/release/stable.txt)
curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
  -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl
kubectl version --client

# ── 7. Terraform ──────────────────────────────────────────────────────────────
echo "▶ Installing Terraform..."
TERRAFORM_VERSION="1.7.5"
curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
  -o /tmp/terraform.zip
unzip -q /tmp/terraform.zip -d /usr/local/bin
chmod +x /usr/local/bin/terraform
terraform version

# ── 8. Node.js 20 & npm ───────────────────────────────────────────────────────
echo "▶ Installing Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
node --version && npm --version

# ── 9. SonarQube Scanner ──────────────────────────────────────────────────────
echo "▶ Installing SonarQube Scanner..."
SONAR_VERSION="5.0.1.3006"
curl -fsSL "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_VERSION}-linux.zip" \
  -o /tmp/sonar-scanner.zip
unzip -q /tmp/sonar-scanner.zip -d /opt
ln -sf /opt/sonar-scanner-${SONAR_VERSION}-linux/bin/sonar-scanner /usr/local/bin/sonar-scanner
sonar-scanner --version

# ── 10. Trivy (extra image scanner) ──────────────────────────────────────────
echo "▶ Installing Trivy..."
curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /usr/share/keyrings/trivy.gpg
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | \
  tee /etc/apt/sources.list.d/trivy.list
apt-get update && apt-get install -y trivy

# ── 11. Restart Jenkins ───────────────────────────────────────────────────────
systemctl restart jenkins

echo ""
echo "════════════════════════════════════════════════════════"
echo "  ✅  Installation complete!"
echo ""
echo "  Jenkins URL  : http://$(curl -s ifconfig.me):8080"
echo "  Admin PW     : $(cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo 'see /var/lib/jenkins/secrets/initialAdminPassword')"
echo "════════════════════════════════════════════════════════"
