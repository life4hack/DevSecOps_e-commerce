## Implementasi DevSecOps aplikasi e-commerce 
Project pembelajaran implementasi DevSecOps dalam aplikasi e-commerce sederhana berbasis Django menggunakan tools security Trivy dan SonarQube

### Tahap belajar
| Proses | Platform |
| -------- | -------- |
| 1. Membuat VM | Googgle Cloud Platform |
| 2. Clone repo | GitHub |
| 3. Mencoba menjalankan aplikasi | Python, Django |
| 4. Membuat docker image dan container | Docker |
| 5. Pengecekan keamanan Docker Image | Trivy |
| 6. Automasi CI/CD + SAST test | Jenkins, SonarQube |



### Tahap 1: Membuat VM
- Membuat sebuah Compute Enginine pada GCP
- Spesifikasi: e2-standard-2, boot disk 25 GB, OS Ubuntu 24.04 LTS 
- Lakukan koneksi SSH ke VM

### Tahap 2 dan 3: Clone repo dan mencoba aplikasi
- Clone aplikasi ke VM: 
```bash
git clone https://github.com/life4hack/DevSecOps_e-commerce.git
```
- Jalankan update repo dan Installasi aplikasi
``` bash
 cd DevSecOps_e-commerce
 sudo apt-get update
 sudo apt-get install python3.12-venv
 python3 -m venv venv
 source venv/bin/activate
 pip install -r requirements.txt
```
> Gunakan .env untuk meletakkan SECRET_KEY
``` bash
 python3 manage.py makemigrations
 python3 manage.py migrate
 python3 manage.py runserver 0.0.0.0:8000
```
- Aplikasi sudah dapat di akses melalui http://{IP_Publik}:8000
- Akses username: admin | password: password123

### Tahap 4: Containerization
- Set up Docker:
```bash
sudo apt-get update
curl -fsSL https://get.docker.com -o install-docker.sh
sudo sh install-docker.sh
sudo usermod -aG docker $USER 
newgrp docker
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
```
- Build Image dan menjalankan Container:

```bash
docker build -t django-ecommerce .
docker run -it -d -p 8000:8000 django-ecommerce 

#untuk stop container dan menghapus image
docker stop <containerid>
docker rmi -f django-ecommerce
```

### Tahap 5: Pengecekan Keamanan Docker Image        
- Install Trivy:
``` bash
sudo apt-get install wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy      
```
- Scan image menggunakan Trivy
```
trivy image <ImageID>
```
Hasil scan Image python:3.12 (debian base)
<img width="709" alt="Screenshot 2024-06-24 at 17 00 46" src="https://github.com/life4hack/DevSecOps_e-commerce/assets/70374232/9dc000b7-e8a6-4a7b-8bc4-5fb0cecae153">

Hasil scan Image python:3.12-alpine (apline linux base)
<img width="837" alt="Screenshot 2024-06-24 at 19 57 21" src="https://github.com/life4hack/DevSecOps_e-commerce/assets/70374232/76956c6b-cf67-41a2-bdc1-7ef6dedbef89">

Terlihat perbedaan vulnerability kedua Image, alpine linux jauh lebih sedikit kerentanan (bahkan nol)

### Tahap 6: SonarQube dan Jenkins   
#### **6.1 Install SonarQube via docker run**

```
docker run -d --name sonar -p 9000:9000 sonarqube:lts-community
```

Akses melalui http://{IP_Publik}:9000 (default username & password = admin)


#### **6.2 Jenkins Setup**

1. **Install Jenkins:**
    - Install Jenkins pada VM instance untuk deployment:
    
    Install Java (required)
    
    ```bash
    sudo apt update
    sudo apt install fontconfig openjdk-17-jre
    java -version
    openjdk version "17.0.8" 2023-07-18
    OpenJDK Runtime Environment (build 17.0.8+7-Debian-1deb12u1)
    OpenJDK 64-Bit Server VM (build 17.0.8+7-Debian-1deb12u1, mixed mode, sharing)
    ```
    Install Jenkins
    ``` bash
    sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
    /etc/apt/sources.list.d/jenkins.list > /dev/null
    sudo apt-get update
    sudo apt-get install jenkins
    sudo systemctl start jenkins
    sudo systemctl enable jenkins
    ```
    
    - Akses Jenkins melalui browser http://{IP_Publik}:8080
        
2. **Install Plugins yang dibituhkan di Jenkins:**

    Manage Jenkins → Plugins → Available Plugins → Install plugins berikut:

    1 Eclipse Temurin Installer 

    2 SonarQube Scanner 

    3 Pyenv Pipeline


#### **Konfigurasi Java pada Global Tool Configuration**

Manage Jenkins → Tools → Install jdk-17 (17.0.8+7) 


#### 6.3 SonarQube

1. Buat secret admin token melalui SonarQube
2. Kembali ke  Jenkins Dashboard → Manage Jenkins → Credentials → Add Secret Text. 
3. Tambahkan sonar-token
4. Click on Apply and Save

| Silakan mengunjungi link referensi #3 dan #4 untuk instruksi lebih jelas

**6.4 Configure CI/CD Pipeline in Jenkins:**
- Membuat pipeline Jenkins untuk clone repo dan analisa SonarQube.

```groovy
pipeline {
    agent any
    tools {
        jdk 'jdk-17'
    }
    environment {
        SCANNER_HOME = tool 'sonar-scanner'
    }
    stages {
        stage('clean workspace') {
            steps {
                cleanWs()
            }
        }
        stage('Checkout from Git') {
            steps {
                git branch: 'main', url: 'https://github.com/life4hack/DevSecOps_e-commerce.git'
            }
        }
        stage("Sonarqube Analysis") {
            steps {
                withSonarQubeEnv('sonar-server') {
                    sh '''$SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=Ecommerce \
                    -Dsonar.projectKey=Ecommerce'''
                }
            }
        }
        stage("quality gate") {
            steps {
                script {
                    waitForQualityGate abortPipeline: false, credentialsId: 'sonar-token'
                }
            }
        }
        stage('Install Dependencies') {
            steps {
                withPythonEnv('/usr/bin/python3.12') {
                    sh "pip install -r requirements.txt"
                }
            }
        }
    }
}
```

Hasil scan source code dengan tools SonarQube

<img width="1108" alt="Screenshot 2024-06-24 at 23 48 01" src="https://github.com/life4hack/DevSecOps_e-commerce/assets/70374232/5fe86c6f-8214-4b05-8194-70024b260b39">




## Sumber / Referensi
1. [YouTube Django Ecommerce App](https://www.youtube.com/watch?v=_ELCMngbM0E&list=PL-51WBLyFTg0omnamUjL1TCVov7yDTRng)
2. [Source code Djanngo App](https://codewithsteps.herokuapp.com/project/cd0492f3-ee93-471a-9dbc-b047233336c3/)
3. [YouTube DevSecOps](https://www.youtube.com/watch?v=g8X5AoqCJHc)
4. [Source Code DevSecOps](https://github.com/N4si/DevSecOps-Project)

