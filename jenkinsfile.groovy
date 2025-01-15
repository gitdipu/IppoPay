pipeline {
    agent any

    environment {
        AWS_ACCOUNT_ID = credentials('AWS_ACCOUNT_ID')
        AWS_REGION = 'us-east-1'
        ECR_REPO = 'react-app'
        DOCKER_IMAGE_NAME = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
        DOCKER_IMAGE_TAG = "${env.BUILD_NUMBER}"
    }

    stages {
        stage('Install Dependencies') {
            steps {
                sh 'npm ci'
            }
        }

        stage('Test') {
            steps {
                sh 'npm run test'
            }
        }

        stage('Build') {
            steps {
                sh 'npm run build'
            }
        }

        stage('Docker Build') {
            steps {
                script {
                    sh """
                        docker build \
                            --build-arg NODE_ENV=production \
                            -t ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} \
                            -t ${DOCKER_IMAGE_NAME}:latest .
                    """
                }
            }
        }

        stage('Push to ECR') {
            steps {
                script {
                    // Login to AWS ECR
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin \
                        ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                    """

                    // Push Docker image to ECR
                    sh """
                        docker push ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}
                        docker push ${DOCKER_IMAGE_NAME}:latest
                    """
                }
            }
        }

        stage('Deploy') {
            steps {
                script {
                    def environments = ['staging', 'production']
                    
                    environments.each { env ->
                        stage("Deploy to ${env}") {
                            withCredentials([
                                string(credentialsId: "${env}_api_url", variable: 'API_URL'),
                                string(credentialsId: "${env}_other_vars", variable: 'OTHER_VARS')
                            ]) {
                                sh """
                                    docker run -d \
                                        -e API_URL=${API_URL} \
                                        -e ENV_NAME=${env} \
                                        -e OTHER_VARS=${OTHER_VARS} \
                                        ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}
                                """
                            }
                        }
                    }
                }
            }
        }
    }

        post {
        success {
            script {
                
                // Email notification for success
                emailext(
                    subject: "✅ Build Successful: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: """
                        <h2>Build Successful!</h2>
                        <p>Job: ${env.JOB_NAME}</p>
                        <p>Build Number: ${env.BUILD_NUMBER}</p>
                        <p>Duration: ${currentBuild.durationString}</p>
                        <p>Image Tag: ${DOCKER_IMAGE_TAG}</p>
                        <p>View Build: <a href='${env.BUILD_URL}'>${env.BUILD_URL}</a></p>
                    """,
                    to: '${DEFAULT_RECIPIENTS}',
                    mimeType: 'text/html'
                )
            }
        }
        
        failure {
            script {
                
                // Email notification for failure
                emailext(
                    subject: "🚨 Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: """
                        <h2>Build Failed!</h2>
                        <p>Job: ${env.JOB_NAME}</p>
                        <p>Build Number: ${env.BUILD_NUMBER}</p>
                        <p>Duration: ${currentBuild.durationString}</p>
                        <p>View Build: <a href='${env.BUILD_URL}'>${env.BUILD_URL}</a></p>
                        <h3>Console Output:</h3>
                        <pre>${currentBuild.rawBuild.getLog(100).join('\n')}</pre>
                    """,
                    to: '${DEFAULT_RECIPIENTS}',
                    mimeType: 'text/html'
                )
            }
        }

        always {
            // Clean up Docker images
            sh """
                docker rmi ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} || true
                docker rmi ${DOCKER_IMAGE_NAME}:latest || true
            """
        }
    }
}
