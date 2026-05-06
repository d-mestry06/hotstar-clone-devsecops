pipeline {
    agent any

    environment {
        AWS_ACCOUNT_ID      = credentials('aws-account-id')
        AWS_REGION          = 'ap-south-1'
        ECR_REPO            = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/hotstar-clone-devsecops-app"
        EKS_CLUSTER         = 'hotstar-clone-devsecops-eks'
        SONAR_PROJECT       = 'hotstar-clone-devsecops'
        IMAGE_TAG           = "${BUILD_NUMBER}-${GIT_COMMIT[0..7]}"
        FULL_IMAGE          = "${ECR_REPO}:${IMAGE_TAG}"
        REACT_APP_TMDB_API_KEY = credentials('tmdb-api-key')
        TRIVY_SEVERITY      = 'HIGH,CRITICAL'
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
                dependencyCheck(
                    additionalArguments: '''
                        --scan .
                        --disableYarnAudit
                        --disableNodeAudit
                        --format HTML
                        --format XML
                        --format JSON
                        --out .
                        --prettyPrint
                    ''',
                    odcInstallation: 'OWASP-DC'
                )
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
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

        stage('OWASP ZAP DAST') {
            steps {
                sh """
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
                sh """
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

    post {
        always {
            deleteDir()
        }
        success {
            echo "Pipeline SUCCESS - Build ${BUILD_NUMBER} deployed"
        }
        failure {
            echo "Pipeline FAILED - Build ${BUILD_NUMBER}"
        }
    }
}
