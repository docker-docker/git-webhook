#!/usr/bin/env groovy
final def releaseTag = (env.TAG_NAME ?: env.BRANCH_NAME).replace('/', '-')
pipeline {
    agent any

    options {
        //ansiColor('xterm')
        timestamps()
    }
    stages {
        stage('Github Code Compile') {
                steps {
                    echo "releaseTag:${releaseTag}"
                    echo 'Building..'
                }
        }
        stage('Docker image build') {
            steps {
                echo 'image building'
               // sh "docker build -f ./src/main/docker/Dockerfile -t tangweiyang/jenkinsdocker:${releaseTag} . "
            }
        }
        stage('Docker image publish') {
            steps {
                echo 'pushing docker hub'
               //sh "docker push tangweiyang/jenkinsdocker:${releaseTag} "
            }
        }
        stage('Stop docker container') {
            steps {
                echo 'stopping container'
            //sh '''
            //     docker rm -f jenkinsdocker &> /dev/null
            //'''
            }
        }
        stage('Deploy docker') {
            steps {
                echo 'deploying'
               // sh "docker run -it -d -p 8081:80 --name jenkinsdocker tangweiyang/jenkinsdocker:${releaseTag}"
            }
        }
    }
}
