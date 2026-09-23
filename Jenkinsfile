pipeline {
    agent any

    parameters {
        booleanParam(name: 'PUSH_IMAGE', defaultValue: false, description: 'Push the image to a registry')
        string(name: 'REGISTRY', defaultValue: 'docker.io/your-user', description: 'Registry/namespace to push to')
        string(name: 'HOST_PORT', defaultValue: '8080', description: 'Host port to expose nginx on')
    }

    environment {
        IMAGE_NAME     = 'nginx-web'
        IMAGE_TAG      = "${env.BUILD_NUMBER}"
        CONTAINER_NAME = 'nginx-web'
        TEST_CONTAINER = "nginx-web-test-${env.BUILD_NUMBER}"
    }

    options {
        timestamps()
        timeout(time: 20, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Image') {
            steps {
                sh '''
                    docker build \
                      -t ${IMAGE_NAME}:${IMAGE_TAG} \
                      -t ${IMAGE_NAME}:latest .
                '''
            }
        }

        stage('Smoke Test') {
            steps {
                sh '''
                    docker run -d --name ${TEST_CONTAINER} ${IMAGE_NAME}:${IMAGE_TAG}

                    # Curl from a helper container sharing the test container's network,
                    # so this works even when Jenkins itself runs inside Docker.
                    for i in $(seq 1 10); do
                      if docker run --rm --network container:${TEST_CONTAINER} \
                           curlimages/curl:8.10.1 -fsS http://localhost/ > /dev/null; then
                        echo "nginx responded OK"
                        exit 0
                      fi
                      echo "Waiting for nginx... ($i)"
                      sleep 2
                    done

                    echo "nginx did not respond"
                    docker logs ${TEST_CONTAINER}
                    exit 1
                '''
            }
            post {
                always {
                    sh 'docker rm -f ${TEST_CONTAINER} || true'
                }
            }
        }

        stage('Push Image') {
            when { expression { return params.PUSH_IMAGE } }
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-registry-creds',
                                                  usernameVariable: 'REG_USER',
                                                  passwordVariable: 'REG_PASS')]) {
                    sh '''
                        REGISTRY_HOST=$(echo "${REGISTRY}" | cut -d/ -f1)
                        echo "$REG_PASS" | docker login "$REGISTRY_HOST" -u "$REG_USER" --password-stdin

                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY}/${IMAGE_NAME}:latest
                        docker push ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${REGISTRY}/${IMAGE_NAME}:latest

                        docker logout "$REGISTRY_HOST"
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                sh '''
                    docker rm -f ${CONTAINER_NAME} || true
                    docker run -d \
                      --name ${CONTAINER_NAME} \
                      --restart unless-stopped \
                      -p ${HOST_PORT}:80 \
                      ${IMAGE_NAME}:${IMAGE_TAG}
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    sleep 3
                    docker run --rm --network container:${CONTAINER_NAME} \
                      curlimages/curl:8.10.1 -fsS http://localhost/ | head -n 20
                '''
            }
        }
    }

    post {
        success {
            echo "nginx is running: http://<jenkins-host>:${params.HOST_PORT}/ (image ${IMAGE_NAME}:${IMAGE_TAG})"
        }
        failure {
            echo 'Pipeline failed. Check the stage logs above.'
        }
        always {
            sh 'docker image prune -f || true'
        }
    }
}
