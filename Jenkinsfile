pipeline {
    agent any

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'prod'], description: 'Target environment')
        booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: 'Skip unit/integration tests')
    }

    environment {
        AWS_REGION      = 'us-east-1'
        ECR_REGISTRY    = "${env.ECR_REGISTRY_URI}"       // set as a Jenkins global env var
        EKS_CLUSTER     = 'springboot-eks-cluster'
        NAMESPACE       = 'microservices'
        SERVICES        = 'user-service,product-service,order-service'
        IMAGE_TAG       = "${env.BUILD_NUMBER}-${env.GIT_COMMIT?.take(7) ?: 'local'}"
        SONARQUBE_ENV   = 'sonarqube-server'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timeout(time: 45, unit: 'MINUTES')
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Detect Changed Services') {
            steps {
                script {
                    def allServices = env.SERVICES.split(',')
                    def changed = sh(
                        script: "git diff --name-only HEAD~1 HEAD || true",
                        returnStdout: true
                    ).trim()
                    env.SERVICES_TO_BUILD = allServices.findAll { svc ->
                        changed.contains("services/${svc}/") || params.ENVIRONMENT == 'prod'
                    }.join(',') ?: env.SERVICES
                    echo "Building: ${env.SERVICES_TO_BUILD}"
                }
            }
        }

        stage('Build & Unit Test') {
            when { expression { !params.SKIP_TESTS } }
            steps {
                script {
                    env.SERVICES_TO_BUILD.split(',').each { svc ->
                        dir("services/${svc}") {
                            sh 'mvn -B clean verify'
                            junit '**/target/surefire-reports/*.xml'
                            jacoco execPattern: '**/target/jacoco.exec'
                        }
                    }
                }
            }
        }

        stage('Static Analysis') {
            steps {
                withSonarQubeEnv("${SONARQUBE_ENV}") {
                    script {
                        env.SERVICES_TO_BUILD.split(',').each { svc ->
                            dir("services/${svc}") {
                                sh 'mvn -B sonar:sonar'
                            }
                        }
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Dependency & Container Scan') {
            steps {
                script {
                    env.SERVICES_TO_BUILD.split(',').each { svc ->
                        dir("services/${svc}") {
                            sh 'mvn -B org.owasp:dependency-check-maven:check'
                        }
                    }
                }
            }
        }

        stage('Build & Push Images') {
            steps {
                script {
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
                    env.SERVICES_TO_BUILD.split(',').each { svc ->
                        dir("services/${svc}") {
                            sh """
                                docker build -t ${ECR_REGISTRY}/${svc}:${IMAGE_TAG} .
                                docker push ${ECR_REGISTRY}/${svc}:${IMAGE_TAG}
                            """
                        }
                    }
                }
            }
        }

        stage('Scan Image (Trivy)') {
            steps {
                script {
                    env.SERVICES_TO_BUILD.split(',').each { svc ->
                        sh "trivy image --severity HIGH,CRITICAL --exit-code 1 ${ECR_REGISTRY}/${svc}:${IMAGE_TAG}"
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    sh "aws eks update-kubeconfig --name ${EKS_CLUSTER} --region ${AWS_REGION}"
                    def imageOverrides = env.SERVICES_TO_BUILD.split(',').collect { svc ->
                        "--set services.${svc}.image.tag=${IMAGE_TAG}"
                    }.join(' ')
                    sh """
                        helm upgrade --install microservices ./helm/microservices \
                          --namespace ${NAMESPACE} --create-namespace \
                          -f ./helm/microservices/values.yaml \
                          -f ./helm/microservices/values-${params.ENVIRONMENT}.yaml \
                          --set global.imageRegistry=${ECR_REGISTRY} \
                          ${imageOverrides} \
                          --wait --timeout 5m
                    """
                }
            }
        }

        stage('Smoke Test') {
            steps {
                script {
                    env.SERVICES_TO_BUILD.split(',').each { svc ->
                        sh "kubectl rollout status deployment/${svc} -n ${NAMESPACE} --timeout=120s"
                    }
                }
                sh './scripts/load-test.sh https://api.example.com 20s 5'
            }
        }
    }

    post {
        success {
            slackSend(channel: '#deployments', color: 'good',
                message: "Deployed ${env.SERVICES_TO_BUILD} to ${params.ENVIRONMENT} (build ${env.BUILD_NUMBER})")
        }
        failure {
            slackSend(channel: '#deployments', color: 'danger',
                message: "Build/Deploy FAILED for ${params.ENVIRONMENT} (build ${env.BUILD_NUMBER}) - ${env.BUILD_URL}")
        }
        always {
            cleanWs()
        }
    }
}
