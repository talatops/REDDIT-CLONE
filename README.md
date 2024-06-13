## Deploying a Reddit Clone to AWS EKS with Jenkins and Trivy

This project demonstrates how to deploy a Reddit clone application using AWS EKS (Elastic Kubernetes Service) with Jenkins as the CI/CD tool. The deployment includes various steps such as installing necessary tools, setting up Jenkins, configuring the pipeline, and scanning the Kubernetes cluster with Trivy for security vulnerabilities.
### Prerequisites

- AWS account
- AWS CLI installed
- IAM role with administrative access
- An Ubuntu 22.04 instance (T2 Large) on AWS
- MobaXterm or PuTTY for SSH access

### Step 1: Launch an Ubuntu EC2 Instance

1. **Launch an AWS T2 Large Instance**:
    
    - Use the Ubuntu 22.04 image.
    - Create a new key pair or use an existing one.
    - Enable HTTP and HTTPS in the Security Group and open all ports for learning purposes.
2. **Create an IAM Role**:
    
    - Go to the IAM dashboard, click on roles, and create a new role.
    - Select AWS service as the trusted entity, and EC2 as the use case.
    - Attach the `AdministratorAccess` policy for learning purposes.
    - Name the role and create it.
    - Attach this role to the EC2 instance.

### Step 2: Connect to the Instance and Install Tools

1. **Install Jenkins, Docker, and Trivy**:
    
    - SSH into your instance using MobaXterm or PuTTY.
    - Update and install Jenkins:
```
sudo apt update -y
wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo tee /etc/apt/keyrings/adoptium.asc
sudo apt update -y
sudo apt install temurin-17-jdk -y
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update -y
sudo apt-get install jenkins -y
sudo systemctl start jenkins

```
### Install Docker:
```
sudo apt-get update
sudo apt-get install docker.io -y
sudo usermod -aG docker $USER
newgrp docker
sudo chmod 777 /var/run/docker.sock
```
### Run SonarQube:
    
`docker run -d --name sonar -p 9000:9000 sonarqube:lts-community`
    
### Install Trivy, Terraform, and kubectl:
```
sudo apt-get install wget apt-transport-https gnupg lsb-release -y
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb/debian buster main" | sudo tee /etc/apt/sources.list.d/trivy.list > /dev/null
sudo apt-get update
sudo apt-get install trivy -y
sudo apt-get install wget -y
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install terraform
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```
    

### Step 3: Configure Jenkins

1. **Open Jenkins**:
    
    - Open port 8080 in your EC2 security group.
    - Access Jenkins at `http://<EC2 Public IP>:8080`.
    - Unlock Jenkins using the administrative password from `/var/lib/jenkins/secrets/initialAdminPassword`.
    - Install suggested plugins and create an admin user.
2. **Install Necessary Jenkins Plugins**:
    
    - Navigate to Manage Jenkins → Manage Plugins → Available Plugins and install:
        - Eclipse Temurin Installer
        - SonarQube Scanner
        - NodeJs Plugin
        - Docker, Docker Commons, Docker Pipeline, Docker API, Docker Build Step
        - OWASP Dependency-Check
        - Terraform
        - Kubernetes, Kubernetes CLI, Kubernetes Client API, Kubernetes Pipeline DevOps steps
3. **Configure Tools in Jenkins**:
    
    - Go to Manage Jenkins → Global Tool Configuration.
    - Install JDK 17 and NodeJs 16.
    - Add SonarQube Scanner.
4. **Configure SonarQube**:
    
    - Access SonarQube at `http://<EC2 Public IP>:9000` and create a token.
    - Add this token in Jenkins under Manage Jenkins → Credentials as a secret text.

### Step 4: Create and Configure the Pipeline

1. **Create EKS Cluster Pipeline**:
    
    - Create a new Jenkins job and add the following pipeline script:
```
    pipeline {
    agent any
    stages {
        stage('Checkout from Git') {
            steps {
                git branch: 'main', url: 'https://github.com/CYBERCODERoss/REDDIT-CLONE.git'
            }
        }
        stage('Terraform Init') {
            steps {
                dir('Eks-terraform') {
                    sh 'terraform init'
                }
            }
        }
        stage('Terraform Apply') {
            steps {
                dir('Eks-terraform') {
                    sh 'terraform apply --auto-approve'
                }
            }
        }
    }
}
```
    
2. **Create Reddit Clone Deployment Job**:
    
    - Add the following stage to deploy the Reddit clone:
```
pipeline{
    agent any
    tools{
        jdk 'jdk17'
        nodejs 'node16'
    }

    environment {
        SCANNER_HOME=tool 'sonar-scanner'
    }

    stages {
        stage('clean workspace'){
            steps{
                cleanWs()
            }
        }

        stage('Checkout from Git'){
            steps{
                git branch: 'main', url: 'https://github.com/CYBERCODERoss/REDDIT-CLONE.git'
            }
        }

        stage('Install Dependencies') {
            steps {
                sh "npm install"
            }
        }

        stage("Sonarqube Analysis "){
            steps{
                withSonarQubeEnv('sonar-server') {
                    sh ''' $SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=Reddit \
                    -Dsonar.projectKey=Reddit '''
                }
            }
        }

        stage("quality gate"){
           steps {
                script {
                    waitForQualityGate abortPipeline: false, credentialsId: 'sonar-token'
                }
            }
        }

        stage('OWASP FS SCAN') {
            steps {
                script {
                    // Define the NVD API key directly or as a credential in Jenkins
                    def nvdApiKey = '<add nvdAPIKey>'

                    // Set the NVD API key as an environment variable
                    withEnv(["NVD=${nvdApiKey}"]) {
                        // Run OWASP Dependency-Check scan with the API key
                        def scanResult = dependencyCheck additionalArguments: "--scan ./ --disableYarnAudit --disableNodeAudit --nvdApiKey $NVD", odcInstallation: 'DP-Check'
                        echo "Dependency-Check scan completed successfully."
                        echo "Result: $scanResult"
                    }
                }
            }
        }

        stage('TRIVY FS SCAN') {
            steps {
                sh "trivy fs . > trivyfs.txt"
            }
        }

        stage("Docker Build & Push"){
            steps{
                script{
                   withDockerRegistry(credentialsId: 'docker', toolName: 'docker'){
                       sh "docker build -t reddit ."
                       sh "docker tag reddit nautilushell/reddit:latest "
                       sh "docker push nautilushell/reddit:latest "
                    }
                }
            }
        }

        stage("TRIVY"){
            steps{
                sh "trivy image --scanners vuln nautilushell/reddit:latest > trivy.txt"
            }
        }

        stage('Deploy to container'){
            steps{
                sh 'docker run -d --name reddit -p 3000:3000 nautilushell/reddit:latest'
            }
        }

        stage('Deploy to kubernets'){
            steps{
                script{
                    withKubeConfig(caCertificate: '', clusterName: '', contextName: '', credentialsId: 'k8s', namespace: '', restrictKubeConfigAccess: false, serverUrl: '') {
                       sh 'kubectl apply -f deployment.yml'
                       sh 'kubectl apply -f service.yml'
                       sh 'kubectl apply -f ingress.yml'
                  }
                }
            }
        }
    }
}
```
### Step 5: Access the Application

1. **Open the Application**:
    - Ensure the load balancer port is open.
    - Access the application at `http://<LoadBalancer Public IP>:3000`.

### Step 6: Scan Kubernetes Cluster with Trivy

1. **Run Trivy Scan**:
    
    - SSH into the Jenkins instance and run:
   
    `trivy k8s --report summary cluster`
    

### Step 7: Terminate the Setup

1. **Delete the EKS Cluster**:
    - In Jenkins, run the EKS job with the parameter set to destroy.
    - Delete the EC2 instance for Jenkins.
