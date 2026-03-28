#!/bin/bash
set -e

echo "===> Setting up repositories"

# PostgreSQL repo
useradd postgres
dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm

# Disable built-in PostgreSQL module to avoid conflicts
dnf module disable -y postgresql

# EPEL + CodeReady Builder
dnf install -y oracle-epel-release-el9
dnf config-manager --set-enabled ol9_codeready_builder

# Terraform (HashiCorp)
dnf install -y dnf-plugins-core
dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo

dnf clean all
dnf makecache

echo "===> Installing packages"
dnf install -y \
  cmake git java-21-openjdk maven terraform \
  postgresql18-server postgresql18-devel postgresql18-contrib \
  pgvector_18 orafce_18 \
  python3-devel python3-pip python3-virtualenv \
  openssl-devel fontconfig-devel libXrender-devel \
  mesa-libGLU perl-devel libnsl2 libnsl2-devel \
  compat-openssl11

echo "===> Initializing PostgreSQL 18 database"
PGSETUP_INITDB_OPTIONS="--encoding=UTF8 --locale=en_US.UTF-8" \
  /usr/pgsql-18/bin/postgresql-18-setup initdb

echo "===> Enabling and starting services"
systemctl enable --now postgresql-18


echo "===> Firewall rules"
firewall-cmd --permanent --add-port=5432/tcp   # PostgreSQL (restrict later)
firewall-cmd --reload

echo "===> Verifying installations"
psql --version
java -version
terraform version

echo ""
echo "===> Done"
echo "PostgreSQL data dir     : /var/lib/pgsql/18/data"


# Jenkins repo - clean any stale key first

rpm --erase gpg-pubkey-ef5975ca* 2>/dev/null || true
curl -fsSL https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key \
  | tee /etc/pki/rpm-gpg/RPM-GPG-KEY-jenkins > /dev/null
  
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-jenkins

cat <<EOF > /etc/yum.repos.d/jenkins.repo
[jenkins]
name=Jenkins-stable
baseurl=https://pkg.jenkins.io/redhat-stable
enabled=1
gpgcheck=0
EOF

systemctl enable --now jenkins

firewall-cmd --permanent --add-port=8080/tcp   # Jenkins
firewall-cmd --reload

jenkins --version 2>/dev/null || systemctl is-active jenkins

echo "Jenkins initial password: $(cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo 'not ready yet — check after service starts')"


[root@oel9 ~]# echo "Jenkins initial password: $(cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo 'not ready yet — check after service starts')"
Jenkins initial password: d91da9de1d304b6eb3ef9d0fec3631dc
[root@oel9 ~]#


One-time setup: SSH key auth for private repo

# On the OEL9 box, generate a deploy key
ssh-keygen -t ed25519 -C "jenkins-samplebank" -f ~/.ssh/samplebank_deploy -N ""
cat ~/.ssh/samplebank_deploy.pub
# Add this public key to GitHub repo → Settings → Deploy Keys → Allow write access

# Configure SSH to use it
cat <<EOF >> ~/.ssh/config
Host github.com
  IdentityFile ~/.ssh/samplebank_deploy
  StrictHostKeyChecking no
EOF
chmod 600 ~/.ssh/config

# Test
ssh -T git@github.com

Sample output
==============

[root@oel9 ~]# ssh -T git@github.com
Warning: Permanently added 'github.com' (ED25519) to the list of known hosts.
Hi postgreshelp/track_3_software! You've successfully authenticated, but GitHub does not provide shell access.
[root@oel9 ~]#

Version 1 — Clone, build, test, push
-----------------------------------------

cd /opt

# Clone via SSH (private repo)
git clone git@github.com:YOUR_ORG/samplebank.git samplebank
cd samplebank

# Confirm you're on main/master
git branch

# Build and test
mvn clean package -DskipTests=false

echo "BUILD: v1 - $(date '+%Y-%m-%d %H:%M:%S') - PASSED" >> build_results.log
git add build_results.log
git commit -m "ci: v1 mvn clean package - PASSED"
git push origin main

## test it
java -jar samplebank-1.0.0.jar

