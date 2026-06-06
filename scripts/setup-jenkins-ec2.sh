#!/usr/bin/env bash
set -euo pipefail

log() {
    echo ""
    echo "====================================================="
    echo "[INFO] $1"
    echo "====================================================="
}

CODENAME=$(lsb_release -cs)

#########################################
# System Update
#########################################
log "Updating system"

apt-get update -y
apt-get upgrade -y

apt-get install -y \
curl \
wget \
git \
jq \
unzip \
gnupg \
ca-certificates \
lsb-release \
apt-transport-https \
software-properties-common \
fontconfig

#########################################
# Java 21
#########################################
log "Installing Java 21"

apt-get install -y openjdk-21-jdk

java -version

#########################################
# Jenkins
#########################################
log "Installing Jenkins"

mkdir -p /etc/apt/keyrings

curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key | \
gpg --dearmor -o /etc/apt/keyrings/jenkins.gpg

chmod 644 /etc/apt/keyrings/jenkins.gpg

echo "deb [signed-by=/etc/apt/keyrings/jenkins.gpg] \
https://pkg.jenkins.io/debian-stable binary/" \
> /etc/apt/sources.list.d/jenkins.list

apt-get update -y

apt-get install -y jenkins

systemctl enable --now jenkins

#########################################
# Docker
#########################################
log "Installing Docker"

mkdir -p /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
| gpg --dearmor -o /etc/apt/keyrings/docker.gpg

chmod a+r /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
> /etc/apt/sources.list.d/docker.list

apt-get update -y

apt-get install -y \
docker-ce \
docker-ce-cli \
containerd.io \
docker-buildx-plugin \
docker-compose-plugin

systemctl enable --now docker

usermod -aG docker ubuntu
usermod -aG docker jenkins

#########################################
# Docker Scout
#########################################
log "Installing Docker Scout"

curl -fsSL https://raw.githubusercontent.com/docker/scout-cli/main/install.sh \
| sh -s --
#########################################
# AWS CLI v2
#########################################
log "Installing AWS CLI"

if command -v aws >/dev/null 2>&1; then
    echo "AWS CLI already installed. Updating..."

    rm -rf aws
    rm -f awscliv2.zip

    curl -s \
    "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
    -o awscliv2.zip

    unzip -q awscliv2.zip

    ./aws/install --update

    rm -rf aws awscliv2.zip

else
    curl -s \
    "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
    -o awscliv2.zip

    unzip -q awscliv2.zip

    ./aws/install

    rm -rf aws awscliv2.zip
fi

aws --version

#########################################
# kubectl
#########################################
log "Installing kubectl"

KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)

curl -LO \
https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl

install -m 0755 kubectl /usr/local/bin/kubectl

rm kubectl

kubectl version --client

#########################################
# Helm
#########################################
log "Installing Helm"

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

helm version

#########################################
# eksctl
#########################################
log "Installing eksctl"

ARCH=amd64
PLATFORM=$(uname -s)_$ARCH

curl -sLO \
https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_${PLATFORM}.tar.gz

tar -xzf eksctl_${PLATFORM}.tar.gz

mv eksctl /usr/local/bin

rm eksctl_${PLATFORM}.tar.gz

eksctl version

#########################################
# Terraform
#########################################
log "Installing Terraform"

curl -fsSL https://apt.releases.hashicorp.com/gpg \
| gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg

echo \
"deb [signed-by=/usr/share/keyrings/hashicorp.gpg] \
https://apt.releases.hashicorp.com ${CODENAME} main" \
> /etc/apt/sources.list.d/hashicorp.list

apt-get update -y

apt-get install -y terraform

terraform version

#########################################
# NodeJS 20
#########################################
log "Installing NodeJS"

curl -fsSL https://deb.nodesource.com/setup_20.x | bash -

apt-get install -y nodejs

node -v
npm -v

#########################################
# Sonar Scanner
#########################################
log "Installing Sonar Scanner"

SONAR_VERSION=5.0.1.3006

curl -fsSL \
https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_VERSION}-linux.zip \
-o sonar-scanner.zip

unzip sonar-scanner.zip -d /opt

ln -sf \
/opt/sonar-scanner-${SONAR_VERSION}-linux/bin/sonar-scanner \
/usr/local/bin/sonar-scanner

rm sonar-scanner.zip

sonar-scanner --version

#########################################
# Trivy
#########################################
log "Installing Trivy"

curl -fsSL \
https://aquasecurity.github.io/trivy-repo/deb/public.key \
| gpg --dearmor -o /usr/share/keyrings/trivy.gpg

echo \
"deb [signed-by=/usr/share/keyrings/trivy.gpg] \
https://aquasecurity.github.io/trivy-repo/deb generic main" \
> /etc/apt/sources.list.d/trivy.list

apt-get update -y

apt-get install -y trivy

trivy --version

#########################################
# SonarQube
#########################################
log "Installing SonarQube"

if docker ps -a --format '{{.Names}}' | grep -q '^sonarqube$'; then
    docker stop sonarqube || true
    docker rm sonarqube || true
fi

docker volume create sonarqube_data
docker volume create sonarqube_logs
docker volume create sonarqube_extensions

docker pull sonarqube:26.5.0.122743-community

docker run -d \
--name sonarqube \
--restart unless-stopped \
-p 9000:9000 \
-e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
-v sonarqube_data:/opt/sonarqube/data \
-v sonarqube_logs:/opt/sonarqube/logs \
-v sonarqube_extensions:/opt/sonarqube/extensions \
sonarqube:26.5.0.122743-community
#########################################
# Restart Jenkins
#########################################
log "Restarting Jenkins"

systemctl restart jenkins

#########################################
# Public IP
#########################################
TOKEN=$(curl -X PUT \
http://169.254.169.254/latest/api/token \
-H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

PUBLIC_IP=$(curl -s \
-H "X-aws-ec2-metadata-token:$TOKEN" \
http://169.254.169.254/latest/meta-data/public-ipv4)

#########################################
# Finished
#########################################
echo ""
echo "====================================================="
echo "DEVSECOPS SETUP COMPLETED"
echo "====================================================="
echo ""
echo "Jenkins    : http://${PUBLIC_IP}:8080"
echo "SonarQube  : http://${PUBLIC_IP}:9000"
echo ""
echo "Initial Jenkins Password:"
cat /var/lib/jenkins/secrets/initialAdminPassword
echo ""
echo "Default SonarQube credentials:"
echo "Username : admin"
echo "Password : admin"
echo ""
echo "====================================================="