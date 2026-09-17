pipeline {
    agent any

    environment {
        WEB_SERVER_IP = "3.7.56.229"
        WEB_SERVER_USER = "ubuntu"
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
                script {
                    echo ">> [4/10] Probing PostgreSQL health on ${WEB_SERVER_IP}:5432..."
                    
                    def keyPath = sh(
                        script: '''
                            KEY_FOUND=""
                            for k in /var/lib/jenkins/.ssh/id_rsa \
                                     /var/lib/jenkins/.ssh/id_ed25519 \
                                     /var/lib/jenkins/.ssh/*.pem \
                                     /var/lib/jenkins/*.pem \
                                     /var/lib/jenkins/.ssh/* \
                                     ~/.ssh/id_rsa \
                                     ~/.ssh/*.pem ; do
                                if [ -f "$k" ]; then
                                    chmod 600 "$k" 2>/dev/null || true
                                    if ssh -i "$k" -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@3.7.56.229 "echo SSH_SUCCESS" 2>/dev/null | grep -q "SSH_SUCCESS"; then
                                        KEY_FOUND="$k"
                                        break
                                    fi
                                fi
                            done
                            if [ -z "$KEY_FOUND" ]; then
                                if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@3.7.56.229 "echo SSH_SUCCESS" 2>/dev/null | grep -q "SSH_SUCCESS"; then
                                    KEY_FOUND="NONE"
                                fi
                            fi
                            echo "$KEY_FOUND"
                        ''',
                        returnStdout: true
                    ).trim()

                    echo "Auto-discovered SSH Key Path: '${keyPath}'"
                    env.FOUND_SSH_KEY = keyPath

                    def sshCmd = (keyPath != "" && keyPath != "NONE") ? "ssh -i ${keyPath}" : "ssh"
                    sh """
                        ${sshCmd} -o StrictHostKeyChecking=no ${WEB_SERVER_USER}@${WEB_SERVER_IP} "pg_isready -h localhost -p 5432" || {
                            echo ">> [CRITICAL] PostgreSQL is UNAVAILABLE! Aborting pipeline."
                            exit 1
                        }
                    """
                }
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
                script {
                    echo ">> [6/10] Executing pre-deployment PostgreSQL backup on ${WEB_SERVER_IP}..."
                    def sshCmd = (env.FOUND_SSH_KEY != "" && env.FOUND_SSH_KEY != "NONE") ? "ssh -i ${env.FOUND_SSH_KEY}" : "ssh"
                    sh """
                        ${sshCmd} -o StrictHostKeyChecking=no ${WEB_SERVER_USER}@${WEB_SERVER_IP} "DB_HOST=localhost DB_PASSWORD=postgres /home/ubuntu/database/backup/db-backup.sh"
                    """
                }
            }
        }

        stage('Database Migration') {
            steps {
                script {
                    echo ">> [7/10] Applying database schema migrations on ${WEB_SERVER_IP}..."
                    def sshCmd = (env.FOUND_SSH_KEY != "" && env.FOUND_SSH_KEY != "NONE") ? "ssh -i ${env.FOUND_SSH_KEY}" : "ssh"
                    sh """
                        ${sshCmd} -o StrictHostKeyChecking=no ${WEB_SERVER_USER}@${WEB_SERVER_IP} "DB_HOST=localhost DB_PASSWORD=postgres /home/ubuntu/database/migrations/migrate.sh"
                    """
                }
            }
        }

        stage('Deploy to Inactive Slot') {
            steps {
                script {
                    echo '>> [8/10] Deploying build to inactive Blue/Green slot...'
                    def sshCmd = (env.FOUND_SSH_KEY != "" && env.FOUND_SSH_KEY != "NONE") ? "ssh -i ${env.FOUND_SSH_KEY}" : "ssh"
                    def scpCmd = (env.FOUND_SSH_KEY != "" && env.FOUND_SSH_KEY != "NONE") ? "scp -i ${env.FOUND_SSH_KEY}" : "scp"

                    def activeEnv = sh(
                        script: "${sshCmd} -o StrictHostKeyChecking=no ${WEB_SERVER_USER}@${WEB_SERVER_IP} 'cat /var/www/active_env.txt 2>/dev/null | grep -o \"blue\\|green\" || echo \"blue\"'",
                        returnStdout: true
                    ).trim()

                    def targetEnv = (activeEnv == 'blue') ? 'green' : 'blue'
                    def targetPort = (targetEnv == 'green') ? '5002' : '5001'

                    echo "Active: ${activeEnv} | Target Deployment Slot: ${targetEnv} (Port ${targetPort})"

                    sh """
                        ${scpCmd} -o StrictHostKeyChecking=no -r ./build-output/backend/* ${WEB_SERVER_USER}@${WEB_SERVER_IP}:/var/www/${targetEnv}/
                        ${sshCmd} -o StrictHostKeyChecking=no ${WEB_SERVER_USER}@${WEB_SERVER_IP} "sudo systemctl restart productapi-${targetEnv}"
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
                    def sshCmd = (env.FOUND_SSH_KEY != "" && env.FOUND_SSH_KEY != "NONE") ? "ssh -i ${env.FOUND_SSH_KEY}" : "ssh"
                    try {
                        sh """
                            ${sshCmd} -o StrictHostKeyChecking=no ${WEB_SERVER_USER}@${WEB_SERVER_IP} "/usr/local/bin/monitoring/health-check.sh http://127.0.0.1:${env.TARGET_PORT}/health"
                        """
                        echo ">> [HEALTH PASSED] Target ${env.TARGET_ENV} verified healthy!"
                    } catch (Exception e) {
                        echo ">> [HEALTH FAILED] Target ${env.TARGET_ENV} probe failed! Initiating Rollback..."
                        sh """
                            ${sshCmd} -o StrictHostKeyChecking=no ${WEB_SERVER_USER}@${WEB_SERVER_IP} "sudo /usr/local/bin/switch-traffic.sh ${env.ACTIVE_ENV}"
                        """
                        error("Deployment halted: ${env.TARGET_ENV} failed health probe. Traffic retained on ${env.ACTIVE_ENV}.")
                    }
                }
            }
        }

        stage('Traffic Switch') {
            steps {
                script {
                    echo ">> [10/10] Switching live production traffic to ${env.TARGET_ENV}..."
                    def sshCmd = (env.FOUND_SSH_KEY != "" && env.FOUND_SSH_KEY != "NONE") ? "ssh -i ${env.FOUND_SSH_KEY}" : "ssh"
                    sh """
                        ${sshCmd} -o StrictHostKeyChecking=no ${WEB_SERVER_USER}@${WEB_SERVER_IP} "sudo /usr/local/bin/switch-traffic.sh ${env.TARGET_ENV}"
                    """
                }
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