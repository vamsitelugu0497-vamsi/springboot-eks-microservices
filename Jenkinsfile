pipeline {
    agent any

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'prod'], description: 'Target environment')
        booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: 'Skip unit tests')
    }

    environment {
        JAVA_HOME = "/usr/lib/jvm/java-21-amazon-corretto.x86_64"
        PATH = "${JAVA_HOME}/bin:/usr/local/bin:/usr/bin:/bin"

        AWS_REGION   = "us-east-1"
        ECR_REGISTRY = "245111010659.dkr.ecr.us-east-1.amazonaws.com"
        EKS_CLUSTER  = "springboot-eks-cluster"
        NAMESPACE    = "microservices"
        SERVICES     = "user-service,product-service,order-service"
        IMAGE_TAG    = "${BUILD_NUMBER}"
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

        stage('Verify Environment') {
            steps {
                sh '''
                    echo "===== JAVA ====="
                    echo "JAVA_HOME=$JAVA_HOME"
                    echo "PATH=$PATH"

                    which java
                    java -version

                    which javac
                    javac -version

                    which mvn
                    mvn -version
                '''
            }
        }

        stage('Build & Test') {
            when {
                expression { !params.SKIP_TESTS }
            }

            steps {
                script {

                    env.SERVICES.split(',').each { svc ->

                        echo "Building ${svc}"

                        dir("services/${svc}") {

                            sh '''
                                export JAVA_HOME=/usr/lib/jvm/java-21-amazon-corretto.x86_64
                                export PATH=$JAVA_HOME/bin:$PATH

                                mvn clean verify
                            '''

                            junit allowEmptyResults: true,
                                  testResults: '**/target/surefire-reports/*.xml'
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
            script {
                sh '''
                    aws sts get-caller-identity
                    aws ecr get-login-password --region us-east-1 | \
                    docker login --username AWS --password-stdin 245111010659.dkr.ecr.us-east-1.amazonaws.com
                '''

                env.SERVICES.split(',').each { svc ->
                    sh """
                        docker build -t ${svc}:${BUILD_NUMBER} services/${svc}

                        docker tag ${svc}:${BUILD_NUMBER} \
                        245111010659.dkr.ecr.us-east-1.amazonaws.com/${svc}:${BUILD_NUMBER}

                        docker push \
                        245111010659.dkr.ecr.us-east-1.amazonaws.com/${svc}:${BUILD_NUMBER}
                    """
                }
            }
        }
    }
}
        stage('Deploy to EKS') {
            steps {

                sh '''
                    aws eks update-kubeconfig \
                    --region ${AWS_REGION} \
                    --name ${EKS_CLUSTER}
                '''

                sh '''
                    helm upgrade --install microservices \
                    ./helm/microservices \
                    --namespace ${NAMESPACE} \
                    --create-namespace \
                    --set global.imageRegistry=${ECR_REGISTRY}
                '''
            }
        }

        stage('Smoke Test') {
            steps {

                script {

                    env.SERVICES.split(',').each { svc ->

                        sh "kubectl rollout status deployment/${svc} -n ${NAMESPACE}"

                    }
                }
            }
        }
    }

    post {

        success {
            echo 'Pipeline completed successfully.'
        }

        failure {
            echo 'Pipeline failed.'
        }

        always {
            cleanWs()
        }
    }
}