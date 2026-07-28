pipeline {
    agent any

    environment {
        JAVA_HOME = "/usr/lib/jvm/java-21-amazon-corretto.x86_64"
        PATH = "${JAVA_HOME}/bin:/usr/local/bin:/usr/bin:/bin"

        AWS_REGION   = "us-east-1"
        ECR_REGISTRY = "245111010659.dkr.ecr.us-east-1.amazonaws.com"

        EKS_CLUSTER  = "devops-eks"
        NAMESPACE    = "microservices"

        SERVICES = "user-service,product-service,order-service"
        IMAGE_TAG = "${BUILD_NUMBER}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Verify Environment') {
            steps {
                sh '''
                java -version
                javac -version
                mvn -version
                docker --version
                aws --version
                '''
            }
        }

        stage('Build & Test') {
            steps {
                script {
                    env.SERVICES.split(',').each { svc ->
                        dir("services/${svc}") {
                            sh '''
                            export JAVA_HOME=/usr/lib/jvm/java-21-amazon-corretto.x86_64
                            export PATH=$JAVA_HOME/bin:$PATH
                            mvn clean verify
                            '''
                        }
                    }
                }
            }
        }

        stage('Docker Build & Push') {
            steps {

                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-creds'
                ]]) {

                    sh '''
                    aws sts get-caller-identity

                    aws ecr get-login-password \
                    --region ${AWS_REGION} | \
                    docker login \
                    --username AWS \
                    --password-stdin ${ECR_REGISTRY}
                    '''

                    script {

                        env.SERVICES.split(',').each { svc ->

                            sh """
                            docker build \
                              -t ${svc}:${IMAGE_TAG} \
                              services/${svc}

                            docker tag \
                              ${svc}:${IMAGE_TAG} \
                              ${ECR_REGISTRY}/${svc}:${IMAGE_TAG}

                            docker push \
                              ${ECR_REGISTRY}/${svc}:${IMAGE_TAG}
                            """
                        }
                    }
                }
            }
        }

        stage('Deploy to EKS') {

            steps {

                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-creds'
                ]]) {

                    sh '''
                    aws sts get-caller-identity

                    aws eks update-kubeconfig \
                        --region ${AWS_REGION} \
                        --name ${EKS_CLUSTER}

                    kubectl get nodes
                    '''

                    script {
                env.SERVICES.split(',').each { svc ->

                    sh """
                        echo "Deploying ${svc}..."

                        kubectl apply -f kubernetes/base/${svc}/configmap.yaml || true
                        kubectl apply -f kubernetes/base/${svc}/secret.yaml || true
                        kubectl apply -f kubernetes/base/${svc}/serviceaccount.yaml || true
                        kubectl apply -f kubernetes/base/${svc}/deployment.yaml
                        kubectl apply -f kubernetes/base/${svc}/service.yaml

                        kubectl rollout status deployment/${svc} -n ${NAMESPACE} --timeout=180s
                    """
                }
                    }
                }
            }
        }

        stage('Smoke Test') {
            steps {
                sh '''
                kubectl get pods -n ${NAMESPACE}
                kubectl get svc -n ${NAMESPACE}
                '''
            }
        }
    }

    post {
        always {
            cleanWs()
        }

        success {
            echo 'Pipeline completed successfully.'
        }

        failure {
            echo 'Pipeline failed.'
        }
    }
}