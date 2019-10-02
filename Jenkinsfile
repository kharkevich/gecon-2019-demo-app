def String determineRepoName() {
    return scm.getUserRemoteConfigs()[0].getUrl().tokenize('/').last().split("\\.")[0]
}

def projectKey = params.containsKey('projectKey') ? params.projectKey : 'gecon'
def registryEndpoint = params.containsKey('registryEndpoint') ? params.registryEndpoint : 'harbor.2019.gecon.by:443'
def registryCredentialsId = params.containsKey('registryCredentialsId') ? params.registryCredentialsId : "harbor-jenkins-robot-account"
def tagName = params.containsKey('tagName') ? params.tagName : "${BRANCH_NAME}"

def stageSwitcher = [
    printEnvironmentVariables : true,
    secretsViolation : [
        credAlert : true,
        detectSecrets : false
        ],
    qualityGates : true,
    publishToMaven : true,
    dockerImage : true,
    upgradeHelmChartDeploymentInRancher : true
    ]


/* Declarative pipeline must be enclosed within a pipeline block */
pipeline {

    environment {
        PROJECT_KEY="$projectKey"
        IMG_REG_URL="$registryEndpoint"
        IMG_REG_CREDS=credentials("$registryCredentialsId")
        IMAGE_NAME= "${determineRepoName()}"
        TAG_NAME="$tagName".replace("/","-")

        // CD pipeline
        RANCHER_API_CREDENTIALS = credentials("rancher-api-credentials")
        RANCHER_TOKEN = "$RANCHER_API_CREDENTIALS_USR:$RANCHER_API_CREDENTIALS_PSW"
        RANCHER_BASE_URL="https://rancher.2019.gecon.by/"
        RANCHER_API_VERSION="3"
        HELM_APP_NAME="gecon-app"
        SERVICE_NAME="application"
    }

    agent {
      kubernetes {
        label "ci-${determineRepoName()}"
        yamlFile 'k8s-ci-pod.yaml'
        defaultContainer 'jnlp'
      }
    }
	triggers {
        pollSCM('H/5 * * * *')
    }

    
    stages {
        stage('Print environment variables') {
            when { expression { "${stageSwitcher.printEnvironmentVariables}" == "true" } }

            steps {
                script {
                    echo sh(script: 'env|sort', returnStdout: true);
                }
            }
        }
        stage('Secrets Violation') {
            parallel {
                stage('Cred Alert'){
                    when { expression { "${stageSwitcher.secretsViolation.credAlert}" == "true" } }

                    steps {
                        container('creds-detect'){
                            sh 'cred-alert scan -f .'
                        }
                    }
                }
                
                stage('Detect Secrets'){
                    when { expression { "${stageSwitcher.secretsViolation.detectSecrets}" == "true" } }

                    steps {
                        container('creds-detect'){
                            sh "detect-secrets scan --all-files > /tmp/secrets-scan-results"
                            sh "cat /tmp/secrets-scan-results"
                            sh "cat /tmp/secrets-scan-results | grep -c 'line_number' && exit 1 || :"
                        }
                    }
                }
            }
        }
        // stage('Unit tests'){
        //     steps{
        //         container('go')
        //         sh "ls -l"
        //         // sh "go test -v"
        //         // sh "go test -v services"
        //     }
        // }
        // stage('SonarQube tests'){
        //     steps{
        //         script {
        //             echo "not implemented yet"
        //         }
        //     }
        // }
        stage('Docker image'){
            when { expression { "${stageSwitcher.dockerImage}" == "true" } }

            steps {
                // BUILD CONTAINER
                container('dnd'){
                    sh "docker build --tag $IMG_REG_URL/$PROJECT_KEY/$IMAGE_NAME:tmp -f Dockerfile ."
                }

                // PUSH CONTAINER
                script {
                    if (!("${BRANCH_NAME}" =~ "PR.*")){

                        def tag1 = "${BRANCH_NAME}" == "master" ? "${BUILD_NUMBER}" : "${TAG_NAME}-${BUILD_NUMBER}"
                        def tag2 = "${BRANCH_NAME}" == "master" ? "latest" : "${TAG_NAME}"

                        container('dnd'){
                            sh "docker tag $IMG_REG_URL/$PROJECT_KEY/$IMAGE_NAME:tmp $IMG_REG_URL/$PROJECT_KEY/$IMAGE_NAME:${tag1}"
                            sh "docker tag $IMG_REG_URL/$PROJECT_KEY/$IMAGE_NAME:tmp $IMG_REG_URL/$PROJECT_KEY/$IMAGE_NAME:${tag2}"
                            sh "docker login -u'${IMG_REG_CREDS_USR}' -p'${IMG_REG_CREDS_PSW}' $IMG_REG_URL"
                            sh "docker push $IMG_REG_URL/$PROJECT_KEY/$IMAGE_NAME:${tag1}"
                            sh "docker push $IMG_REG_URL/$PROJECT_KEY/$IMAGE_NAME:${tag2}"
                        }
                    }
                }

            }
        }
        stage('Upgrade helm chart deployment in Rancher'){
            when { expression { "${stageSwitcher.upgradeHelmChartDeploymentInRancher}" == "true" } }
            
            steps {
                script {
                    if ("${BRANCH_NAME}" == "develop") {
                        container('app-updater') {
                            sh '''
                                export K8S_CLUSTER_NAME=gecon
                                export K8S_PROJECT_NAME="gecon"
                                charts-updater-cli
                            '''
                        }
                    }
                }
            }
        }

    }
}
