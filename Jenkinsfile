pipeline {
    agent any

    environment {
        // ── Update these values ──────────────────────────────────
        AWS_ACCOUNT_ID      = credentials('aws-account-id')
        AWS_REGION          = 'ap-south-1'
        ECR_REPO            = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/hotstar-clone-devsecops-app"
        EKS_CLUSTER         = 'hotstar-clone-devsecops-eks'
        SONAR_PROJECT       = 'hotstar-clone-devsecops'
        // ─────────────────────────────────────────────────────────
        IMAGE_TAG           = "${BUILD_NUMBER}-${GIT_COMMIT[0..7]}"
        FULL_IMAGE          = "${ECR_REPO}:${IMAGE_TAG}"
        TRIVY_SEVERITY      = 'HIGH,CRITICAL'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
    }

    stages {
        // ── 1. Checkout ─────────────────────────────────────────
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git log --oneline -5'
            }
        }

        // ── 2. Install Dependencies ──────────────────────────────
        stage('Install Dependencies') {
            steps {
                sh 'npm ci'
            }
        }

        // ── 3. SonarQube Analysis (SAST) ─────────────────────────
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    sh """
                        sonar-scanner \
                          -Dsonar.projectKey=${SONAR_PROJECT} \
                          -Dsonar.sources=. \
                          -Dsonar.host.url=${SONAR_HOST_URL} \
                          -Dsonar.login=${SONAR_AUTH_TOKEN} \
                          -Dsonar.exclusions='node_modules/**,build/**,**/*.test.js'
                    """
                }
            }
        }

        // ── 4. SonarQube Quality Gate ────────────────────────────
        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        // ── 5. NPM Audit (Dependency Check) ─────────────────────
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

        // ── 6. OWASP Dependency Check ────────────────────────────
        stage('OWASP Dependency Check') {
            steps {
                dependencyCheck(
                    additionalArguments: '''
                        --scan .
                        --disableYarnAudit
                        --disableNodeAudit
                        --format HTML
                        --format JSON
                        --prettyPrint
                    ''',
                    odcInstallation: 'OWASP-DC'
                )
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            }
        }

        // ── 7. Docker Build ──────────────────────────────────────
        stage('Docker Build') {
            steps {
                sh "docker build -t ${FULL_IMAGE} -t ${ECR_REPO}:latest ."
            }
        }

        // ── 8. Docker Scout FS Scan ──────────────────────────────
        stage('Docker Scout FS Scan') {
            steps {
                sh """
                    docker scout cves --format sarif --output scout-fs-report.sarif . || true
                """
                archiveArtifacts artifacts: 'scout-fs-report.sarif', allowEmptyArchive: true
            }
        }

        // ── 9. Docker Scout Image Scan ───────────────────────────
        stage('Docker Scout Image Analysis') {
            steps {
                sh """
                    docker scout cves ${FULL_IMAGE} \
                        --format sarif \
                        --output scout-image-report.sarif || true
                    docker scout recommendations ${FULL_IMAGE} || true
                """
                archiveArtifacts artifacts: 'scout-image-report.sarif', allowEmptyArchive: true
            }
        }

        // ── 10. Trivy Image Scan ─────────────────────────────────
        stage('Trivy Vulnerability Scan') {
            steps {
                sh """
                    trivy image \
                        --severity ${TRIVY_SEVERITY} \
                        --format template \
                        --template "@/usr/local/share/trivy/templates/html.tpl" \
                        --output trivy-report.html \
                        --exit-code 0 \
                        ${FULL_IMAGE}

                    trivy image \
                        --severity CRITICAL \
                        --exit-code 1 \
                        ${FULL_IMAGE}
                """
            }
            post {
                always {
                    publishHTML(target: [
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: '.',
                        reportFiles: 'trivy-report.html',
                        reportName: 'Trivy Security Report'
                    ])
                }
            }
        }

        // ── 11. Push to ECR ──────────────────────────────────────
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

        // ── 12. Deploy to EKS ────────────────────────────────────
        stage('Deploy to EKS') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    sh """
                        aws eks update-kubeconfig \
                            --region ${AWS_REGION} \
                            --name ${EKS_CLUSTER}

                        # Update image tag in manifest
                        sed -i 's|IMAGE_PLACEHOLDER|${FULL_IMAGE}|g' k8s/deployment.yaml

                        kubectl apply -f k8s/

                        kubectl rollout status deployment/hotstar-app -n hotstar --timeout=300s
                    """
                }
            }
        }

        // ── 13. OWASP ZAP DAST ──────────────────────────────────
        stage('OWASP ZAP DAST') {
            steps {
                sh """
                    APP_URL=\$(kubectl get svc hotstar-service -n hotstar -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
                    
                    docker run --rm \
                        -v \$(pwd):/zap/wrk/:rw \
                        ghcr.io/zaproxy/zaproxy:stable \
                        zap-baseline.py \
                        -t http://\${APP_URL} \
                        -r zap-report.html \
                        -x zap-report.xml \
                        --auto || true
                """
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

        // ── 14. Smoke Test ───────────────────────────────────────
        stage('Smoke Test') {
            steps {
                sh """
                    APP_URL=\$(kubectl get svc hotstar-service -n hotstar -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
                    sleep 30
                    curl -f http://\${APP_URL}/health || exit 1
                    echo "Smoke test PASSED"
                """
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            echo "Pipeline SUCCESS - Build ${BUILD_NUMBER} deployed"
        }
        failure {
            echo "Pipeline FAILED - Build ${BUILD_NUMBER}"
            mail(
                to: 'devops@example.com',
                subject: "FAILED: ${JOB_NAME} #${BUILD_NUMBER}",
                body: "Build failed. Check ${BUILD_URL}"
            )
        }
    }
}
