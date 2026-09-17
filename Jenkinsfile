pipeline {
    agent any

    environment {
        WEB_SERVER_IP = "3.7.56.229"
        WEB_SERVER_USER = "ubuntu"
        SSH_KEY = "/var/lib/jenkins/.ssh/id_rsa"
    }

    stages {
        stage('Checkout') {
            steps {
                echo '>> [1/10] Checking out repository source code...'
                checkout scm
            }
        }

        stage('Unit Tests') {
            steps {
                echo '>> [2/10] Running xUnit backend test suite...'
                sh 'dotnet test backend/ProductAPI.Tests/ProductAPI.Tests.csproj --verbosity normal'
            }
        }

        stage('Security Scan (DevSecOps Gate)') {
            steps {
                echo '>> [3/10] Running Secret & SAST Scans...'
                sh 'chmod +x security/scan.sh && ./security/scan.sh'
            }
        }

        stage('Database Pre-flight Check') {
            steps {
                echo ">> [4/10] Probing PostgreSQL health on ${WEB_SERVER_IP}:5432..."
                sh """
                    ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no ${WEB_SERVER_USER}@${WEB_SERVER_IP} "pg_isready -h localhost -p 5432" || {
                        echo ">> [CRITICAL] PostgreSQL is UNAVAILABLE! Aborting pipeline."
                        exit 1
                    }
                """
            }
        }

        stage('Build & Package') {
            steps {
                echo '>> [5/10] Compiling .NET 8 Backend Release Binaries...'
                sh 'dotnet publish backend/ProductAPI.csproj -c Release -o ./build-output/backend'
            }
        }

        stage('Pre-Deployment Backup') {
            steps {
                echo ">> [6/10] Executing pre-deployment PostgreSQL backup on ${WEB_SERVER_IP}..."
                sh """
                    ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no ${WEB_SERVER_USER}@${WEB_SERVER_IP} "DB_HOST=localhost DB_PASSWORD=postgres /home/ubuntu/database/backup/db-backup.sh"
                """
            }
        }

        stage('Database Migration') {
            steps {
                echo ">> [7/10] Applying database schema migrations on ${WEB_SERVER_IP}..."
                sh """
                    ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no ${WEB_SERVER_USER}@${WEB_SERVER_IP} "DB_HOST=localhost DB_PASSWORD=postgres /home/ubuntu/database/migrations/migrate.sh"
                """
            }
        }

        stage('Deploy to Inactive Slot') {
            steps {
                script {
                    echo '>> [8/10] Deploying build to inactive Blue/Green slot...'
                    def activeEnv = sh(
                        script: "ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no ${WEB_SERVER_USER}@${WEB_SERVER_IP} 'cat /var/www/active_env.txt 2>/dev/null | grep -o \"blue\\|green\" || echo \"blue\"'",
                        returnStdout: true
                    ).trim()

                    def targetEnv = (activeEnv == 'blue') ? 'green' : 'blue'
                    def targetPort = (targetEnv == 'green') ? '5002' : '5001'

                    echo "Active: ${activeEnv} | Target Deployment Slot: ${targetEnv} (Port ${targetPort})"

                    sh """
                        scp -i ${SSH_KEY} -o StrictHostKeyChecking=no -r ./build-output/backend/* ${WEB_SERVER_USER}@${WEB_SERVER_IP}:/var/www/${targetEnv}/
                        ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no ${WEB_SERVER_USER}@${WEB_SERVER_IP} "sudo systemctl restart productapi-${targetEnv}"
                    """

                    env.TARGET_ENV = targetEnv
                    env.TARGET_PORT = targetPort
                    env.ACTIVE_ENV = activeEnv
                }
            }
        }

        stage('Automated Health Gate') {
            steps {
                script {
                    echo ">> [9/10] Probing target environment (${env.TARGET_ENV} on Port ${env.TARGET_PORT})..."
                    try {
                        sh """
                            ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no ${WEB_SERVER_USER}@${WEB_SERVER_IP} "/usr/local/bin/monitoring/health-check.sh http://127.0.0.1:${env.TARGET_PORT}/health"
                        """
                        echo ">> [HEALTH PASSED] Target ${env.TARGET_ENV} verified healthy!"
                    } catch (Exception e) {
                        echo ">> [HEALTH FAILED] Target ${env.TARGET_ENV} probe failed! Initiating Rollback..."
                        sh """
                            ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no ${WEB_SERVER_USER}@${WEB_SERVER_IP} "sudo /usr/local/bin/switch-traffic.sh ${env.ACTIVE_ENV}"
                        """
                        error("Deployment halted: ${env.TARGET_ENV} failed health probe. Traffic retained on ${env.ACTIVE_ENV}.")
                    }
                }
            }
        }

        stage('Traffic Switch') {
            steps {
                echo ">> [10/10] Switching live production traffic to ${env.TARGET_ENV}..."
                sh """
                    ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no ${WEB_SERVER_USER}@${WEB_SERVER_IP} "sudo /usr/local/bin/switch-traffic.sh ${env.TARGET_ENV}"
                """
            }
        }
    }

    post {
        success {
            echo "=================================================="
            echo " SUCCESS: Blue-Green Deployment Completed!"
            echo " Live Production URL: http://${WEB_SERVER_IP}"
            echo "=================================================="
        }
        failure {
            echo "=================================================="
            echo " FAILURE: Pipeline Quality Gate Blocked Deployment"
            echo "=================================================="
        }
    }
}