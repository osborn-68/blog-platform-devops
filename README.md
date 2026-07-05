# Cloud-Native Blogging Platform — Complete Beginner Walkthrough

This kit gives you working Terraform, Ansible, a sample app, and a Jenkinsfile.
Follow the steps **in order**. Each step tells you exactly what to click or type.

**Architecture (kept as simple as possible):**
- Public Subnet → Bastion node (runs Jenkins + Ansible) AND App node (runs frontend + backend containers, has a public IP so you can view it in a browser)
- Private Subnet → DB node (MySQL, only reachable from inside the VPC)
- NAT Gateway lets the private DB node download packages during setup

---

## STEP 0 — Prerequisites (do these once, in the AWS Console)

1. **Create an EC2 Key Pair**
   - AWS Console → EC2 → "Key Pairs" → Create key pair
   - Name it e.g. `my-ec2-keypair`, type `.pem`, download it.
   - On your laptop: `chmod 400 ~/Downloads/my-ec2-keypair.pem`

2. **Find your public IP** (so security groups only allow your traffic)
   - Visit https://checkip.amazonaws.com → note the IP → you'll use it as `IP/32`

3. **Install Terraform & AWS CLI on your laptop**
   - Terraform: https://developer.hashicorp.com/terraform/downloads
   - AWS CLI: `pip install awscli` or https://aws.amazon.com/cli/
   - Run `aws configure` and enter your AWS Access Key, Secret Key, and region (`us-east-1`)

4. **Create a free Docker Hub account** → https://hub.docker.com (you'll push images here)

5. **Create a GitHub repo** and push this entire folder to it (Jenkins will pull from it).

---

## STEP 1 — Provision Infrastructure with Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: put your real key_name and my_ip

terraform init
terraform plan
terraform apply     # type "yes" when prompted
```

When it finishes, Terraform prints:
```
bastion_public_ip = "x.x.x.x"
app_private_ip    = "10.0.1.x"
app_public_ip     = "y.y.y.y"
db_private_ip     = "10.0.2.x"
```
**Write these four values down** — you need them for every step below.

---

## STEP 2 — Passwordless SSH Setup

1. Copy your `.pem` key onto the bastion (so Ansible/Jenkins running on the bastion can reach the private app/db nodes):
   ```bash
   scp -i my-ec2-keypair.pem my-ec2-keypair.pem ubuntu@<BASTION_PUBLIC_IP>:~/
   ssh -i my-ec2-keypair.pem ubuntu@<BASTION_PUBLIC_IP>
   chmod 400 ~/my-ec2-keypair.pem
   ```
2. From now on, **all Ansible/Jenkins commands run from inside the bastion.**
3. Quick test — from the bastion:
   ```bash
   ssh -i ~/my-ec2-keypair.pem ubuntu@<APP_PRIVATE_IP> echo "app ok"
   ssh -i ~/my-ec2-keypair.pem ubuntu@<DB_PRIVATE_IP> echo "db ok"
   ```
   Both should print without asking for a password (key-based auth = "passwordless").

---

## STEP 3 — Configuration Management with Ansible

Still **on the bastion**:

```bash
sudo apt update
sudo apt install -y ansible git

git clone https://github.com/<you>/blog-platform-devops.git
cd blog-platform-devops/ansible

ansible-galaxy collection install community.docker community.mysql

cp inventory.ini.example inventory.ini
nano inventory.ini   # replace <APP_PRIVATE_IP> and <DB_PRIVATE_IP> with real values
nano site.yml        # replace REPLACE_WITH_YOUR_DOCKERHUB_USERNAME with your Docker Hub username

# test connectivity first
ansible all -m ping

# run the real thing
ansible-playbook site.yml
```

This installs Docker + Docker Compose and starts the frontend/backend containers on the
App node, and installs + configures MySQL on the DB node.

**Verify:**
```bash
ssh -i ~/my-ec2-keypair.pem ubuntu@<APP_PRIVATE_IP> docker ps
ssh -i ~/my-ec2-keypair.pem ubuntu@<DB_PRIVATE_IP> sudo systemctl status mysql
```

---

## STEP 4 — Jenkins CI/CD (on the Bastion)

### 4a. Install Jenkins
```bash
sudo apt update
sudo apt install -y openjdk-17-jre
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install -y jenkins docker.io
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### 4b. Open Jenkins in your browser
`http://<BASTION_PUBLIC_IP>:8080`
Get the unlock password:
```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```
Choose "Install suggested plugins", then create your admin user.

### 4c. Install required plugins
Manage Jenkins → Plugins → Available plugins → install:
- **Git Plugin** (usually already installed)
- **Docker Pipeline** (the "Docker Plugin")
- **Pipeline** (usually already installed)
- **SSH Agent Plugin** (needed for the deploy stage)

### 4d. Add credentials
Manage Jenkins → Credentials → System → Global credentials → Add:
1. **Docker Hub** — kind "Username with password", ID = `dockerhub-creds`
2. **App node SSH key** — kind "SSH Username with private key", ID = `app-node-ssh-key`,
   paste the contents of `my-ec2-keypair.pem`, username `ubuntu`

### 4e. Create the Pipeline job
- New Item → name it `blog-pipeline` → type "Pipeline"
- Under "Pipeline" → Definition → "Pipeline script from SCM"
- SCM = Git → paste your GitHub repo URL → Script Path = `jenkins/Jenkinsfile`
- Before saving, edit `jenkins/Jenkinsfile` in your repo: replace
  `REPLACE_WITH_YOUR_DOCKERHUB_USERNAME`, the GitHub URL, and
  `REPLACE_WITH_APP_PRIVATE_IP` with your real values, then push.
- Click **Build Now**.

The pipeline will: pull code from GitHub → build both Docker images →
push them to Docker Hub → SSH into the App node and redeploy with
`docker compose pull && up -d`.

### 4f. (Optional) Auto-trigger on new commits
- In your GitHub repo → Settings → Webhooks → Add webhook
- Payload URL: `http://<BASTION_PUBLIC_IP>:8080/github-webhook/`
- Content type: `application/json`, event: "Just the push event"
- In the Jenkins job config, tick **"GitHub hook trigger for GITScm polling"**

---

## STEP 5 — Validation & Screenshots

Capture these for submission:

1. `terraform apply` output showing the 3 required IPs
2. `ansible-playbook site.yml` finishing with `failed=0`
3. `docker ps` on the App node showing frontend + backend containers `Up`
4. Browser screenshot of `http://<APP_PUBLIC_IP>` showing the blog page loading posts
5. Jenkins pipeline "Stage View" showing all green stages
6. Make a small change (e.g. edit `index.html`), `git push`, and screenshot
   Jenkins automatically starting a new build (proves the webhook trigger works)

---

## Troubleshooting Cheatsheet

| Problem | Likely Fix |
|---|---|
| `terraform apply` fails on AMI | Check `availability_zone` matches instances your account can use in that region |
| Can't SSH to bastion | Check your `my_ip` in tfvars matches your CURRENT public IP |
| `ansible all -m ping` fails | Check `inventory.ini` IPs and that the `.pem` is on the bastion with `chmod 400` |
| Browser shows nothing on port 80 | Check App SG allows port 80 from `0.0.0.0/0`, and `docker ps` shows frontend "Up" |
| Backend can't reach MySQL | Check DB SG allows 3306 from App SG, and `bind-address` in mysqld.cnf is `0.0.0.0` |
| Jenkins deploy stage fails to SSH | Confirm `app-node-ssh-key` credential and that Jenkins user's key matches the app node's key pair |

---

## Folder Reference

```
terraform/       -> VPC, subnets, IGW, NAT, security groups, EC2 instances, outputs
ansible/         -> inventory + playbook (Docker install, container deploy, MySQL setup)
sample-app/      -> minimal frontend (Nginx) + backend (Node/Express) + docker-compose
jenkins/         -> Jenkinsfile (build -> push -> deploy pipeline)
```
