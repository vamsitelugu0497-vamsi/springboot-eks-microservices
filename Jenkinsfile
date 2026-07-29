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

                    cp kubernetes/base/${svc}/deployment.yaml /tmp/${svc}-deployment.yaml

                    sed -i "s|<ECR_REPO_URI>|${ECR_REGISTRY}|g" /tmp/${svc}-deployment.yaml
                    sed -i "s|<IMAGE_TAG>|${IMAGE_TAG}|g" /tmp/${svc}-deployment.yaml

                    kubectl apply -f kubernetes/base/${svc}/configmap.yaml
                    kubectl apply -f kubernetes/base/${svc}/secret.yaml
                    kubectl apply -f kubernetes/base/${svc}/serviceaccount.yaml
                    kubectl apply -f /tmp/${svc}-deployment.yaml
                    kubectl apply -f kubernetes/base/${svc}/service.yaml

                    kubectl rollout status deployment/${svc} \
                        -n ${NAMESPACE} \
                        --timeout=300s
                    """
                }
            }
        }
    }
}