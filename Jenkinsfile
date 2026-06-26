pipeline {
    agent any

    environment {
        AWS_ACCOUNT_ID      = credentials('aws-account-id')
        AWS_REGION          = 'ap-south-1'
        ECR_REPO            = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/hotstar-clone-devsecops-app"
        EKS_CLUSTER         = 'hotstar-clone-devsecops-eks'
        SONAR_PROJECT       = 'hotstar-clone-devsecops'
        IMAGE_TAG           = "${BUILD_NUMBER}-${GIT_COMMIT.take(7)}"
        FULL_IMAGE          = "${ECR_REPO}:${IMAGE_TAG}"
        REACT_APP_TMDB_API_KEY = credentials('tmdb-api-key')
        TRIVY_SEVERITY      = 'HIGH,CRITICAL'
        SLACK_CHANNEL       = '#dec-2025-monitoring'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                sh 'git log --oneline -5'
            }
        }

        stage('Install Dependencies') {
            steps {
                sh 'npm install'
                sh 'npm install --package-lock-only'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    script {
                        def scannerHome = tool 'sonar-scanner'
                        sh """${scannerHome}/bin/sonar-scanner \
                          -Dsonar.projectKey=${SONAR_PROJECT} \
                          -Dsonar.sources=. \
                          -Dsonar.host.url=${SONAR_HOST_URL} \
                          -Dsonar.login=${SONAR_AUTH_TOKEN} \
                          -Dsonar.exclusions='node_modules/**,build/**,**/*.test.js'
                        """
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('NPM Audit') {
            steps {
                sh 'npm audit --audit-level=high || true'
                sh 'npm audit --json > npm-audit-report.json || true'
            }
            post {
                always {
                    archiveArtifacts artifacts: 'npm-audit-report.json', allowEmptyArchive: true
                }
            }
        }

        stage('OWASP Dependency Check') {
            steps {
                timeout(time: 120, unit: 'MINUTES') {
                    withCredentials([string(credentialsId: 'nvd-api-key', variable: 'NVD_API_KEY')]) {
                        dependencyCheck(
                            odcInstallation: 'OWASP-DC',
                            additionalArguments: '''
                                --scan .
                                --disableYarnAudit
                                --disableNodeAudit
                                --format HTML
                                --format XML
                                --format JSON
                                --out .
                                --prettyPrint
                                --data /var/lib/dependency-check
                                --nvdApiKey $NVD_API_KEY
                                --nvdApiDelay 2000
                            '''
                        )
                    }
                }
            }

            post {
                always {
                    dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
                    archiveArtifacts artifacts: 'dependency-check-report.*', allowEmptyArchive: true
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh "docker build --build-arg REACT_APP_TMDB_API_KEY=${REACT_APP_TMDB_API_KEY} -t ${FULL_IMAGE} -t ${ECR_REPO}:latest ."
            }
        }

        stage('Trivy FS Scan') {
            steps {
                sh """
                    trivy fs \
                        --severity HIGH,CRITICAL \
                        --format json \
                        --output trivy-fs-report.json \
                        --exit-code 0 \
                        . || true
                """
                archiveArtifacts artifacts: 'trivy-fs-report.json', allowEmptyArchive: true
            }
        }

        stage('Docker Scout Image Analysis') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh """
                        echo \$DOCKER_PASS | docker login -u \$DOCKER_USER --password-stdin
                        docker scout cves ${FULL_IMAGE} || true
                        docker scout recommendations ${FULL_IMAGE} || true
                    """
                }
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh """
                    trivy image \
                        --severity ${TRIVY_SEVERITY} \
                        --format json \
                        --output trivy-image-report.json \
                        --exit-code 0 \
                        ${FULL_IMAGE} || true

                    trivy image \
                        --severity CRITICAL \
                        --exit-code 1 \
                        ${FULL_IMAGE}
                """
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-image-report.json', allowEmptyArchive: true
                }
            }
        }

        stage('Push to ECR') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | \
                            docker login --username AWS --password-stdin ${ECR_REPO}

                        docker push ${FULL_IMAGE}
                        docker push ${ECR_REPO}:latest
                    """
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    sh """
                        aws eks update-kubeconfig \
                            --region ${AWS_REGION} \
                            --name ${EKS_CLUSTER}

                        sed -i 's|IMAGE_PLACEHOLDER|${FULL_IMAGE}|g' k8s/deployment.yaml

                        kubectl apply -f k8s/

                        kubectl rollout status deployment/hotstar-app -n hotstar --timeout=300s
                    """
                }
            }
        }

        stage('Setup Monitoring') {
            when {
                anyOf {
                    branch 'main'
                    expression { env.GIT_BRANCH ==~ /.*main/ }
                }
            }
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials'],
                    string(credentialsId: 'slack-webhook-url',      variable: 'SLACK_WEBHOOK_URL'),
                    string(credentialsId: 'grafana-admin-password', variable: 'GRAFANA_ADMIN_PASSWORD')
                ]) {
                    sh """
                        if ! command -v helm &>/dev/null; then
                            curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
                        fi
                        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
                        helm repo update
                        kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
                        helm upgrade --install prometheus \
                            prometheus-community/kube-prometheus-stack \
                            --namespace monitoring \
                            --version 58.3.0 \
                            --values monitoring/prometheus-values.yaml \
                            --set grafana.adminPassword=\${GRAFANA_ADMIN_PASSWORD} \
                            --set alertmanager.config.global.slack_api_url=\${SLACK_WEBHOOK_URL} \
                            --wait --timeout 10m
                        kubectl apply -f monitoring/alert-rules.yaml
                        kubectl apply -f monitoring/servicemonitor.yaml
                    """
                }
            }
        }

        stage('OWASP ZAP DAST') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    sh """
                        aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}
                        APP_URL=\$(kubectl get svc hotstar-service -n hotstar -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
                        if [ -z "\$APP_URL" ]; then
                            echo "Load Balancer not ready yet, skipping ZAP scan"
                            exit 0
                        fi
                        docker run --rm \
                            --network host \
                            -u root \
                            -v \$(pwd):/zap/wrk/:rw \
                            ghcr.io/zaproxy/zaproxy:stable \
                            zap-baseline.py \
                            -t http://\${APP_URL} \
                            -r zap-report.html \
                            -x zap-report.xml \
                            --auto || true
                    """
                }
            }
            post {
                always {
                    publishHTML(target: [
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: '.',
                        reportFiles: 'zap-report.html',
                        reportName: 'OWASP ZAP Report'
                    ])
                }
            }
        }

        stage('Smoke Test') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    sh """
                        aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}
                        echo "Waiting for Load Balancer to provision..."
                        for i in \$(seq 1 20); do
                            APP_URL=\$(kubectl get svc hotstar-service -n hotstar -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
                            if [ -n "\$APP_URL" ]; then
                                echo "Load Balancer ready: \$APP_URL"
                                sleep 10
                                curl -f http://\${APP_URL}/health && echo "Smoke test PASSED" && exit 0
                            fi
                            echo "Waiting... attempt \$i/20"
                            sleep 15
                        done
                        echo "Load Balancer not ready after 5 minutes"
                        exit 1
                    """
                }
            }
        }
    }

    post {
        always {
            deleteDir()
            slackSend(
                channel: env.SLACK_CHANNEL,
                color: currentBuild.currentResult == 'SUCCESS' ? 'good' : currentBuild.currentResult == 'FAILURE' ? 'danger' : 'warning',
                message: "Hotstar DevSecOps Pipeline | Build #${BUILD_NUMBER}\nStatus: ${currentBuild.currentResult}\nBranch: ${GIT_BRANCH}\nDuration: ${currentBuild.durationString}\nLogs: ${BUILD_URL}console"
            )
        }
        success {
            slackSend(
                channel: env.SLACK_CHANNEL,
                color: 'good',
                message: ":white_check_mark: Deployment Successful - Build #${BUILD_NUMBER} is live on EKS. ${BUILD_URL}"
            )
        }
        failure {
            slackSend(
                channel: env.SLACK_CHANNEL,
                color: 'danger',
                message: ":x: Pipeline Failed - Build #${BUILD_NUMBER} | Branch: ${GIT_BRANCH} | ${BUILD_URL}console"
            )
        }
        unstable {
            slackSend(
                channel: env.SLACK_CHANNEL,
                color: 'warning',
                message: ":warning: Pipeline Unstable - Build #${BUILD_NUMBER} | Branch: ${GIT_BRANCH} | ${BUILD_URL}"
            )
        }
    }
}
