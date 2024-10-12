#!/bin/bash

#Update the system and install necessary packages
#Keeping the system updated is critical for security, as it ensures all software is up-to-date with the latest patches.
echo "[TASK 1] Update system and install required packages"
apt-get update && apt-get upgrade -y
apt-get install -y apt-transport-https ca-certificates curl

# Remove Docker during reprovisioning
echo "[TASK] Removing Docker if it exists"
apt-get remove -y docker docker-engine docker.io containerd runc
apt-get purge -y docker-ce docker-ce-cli
rm -rf /var/lib/docker

# Disable swap
echo "[TASK 2] Disable swap"
swapoff -a
sed -i '/swap/d' /etc/fstab

# Disable Firewall
#echo "[TASK 3] Disable UFW"
#systemctl disable --now ufw

# Enable and Load Kernel modules
echo "[TASK 4] Enable and load kernel modules"
cat <<EOF | tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# Add Kernel settings
echo "[TASK 5] Add kernel settings"
cat <<EOF | tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# Install containerd runtime
echo "[TASK 7] Install containerd"
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Configure SSH for security
# disabling root login and password authentication.
# Disabling root login prevents unauthorized access to the server
# Disabling password authentication ensures SSH keys are required for access, further improving security.
echo "[TASK 8] Configure SSH for security"
sed -i 's/^PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl reload sshd

# Creating a new user, kubeuser with sudo privileges and setting a password.
# Using a non-root user for regular operations is a best practice in security. It limits the potential damage in case of a compromise.
echo "[TASK 9] Create a new user with sudo privileges"
adduser kubeuser --gecos "First Last,email" --disabled-password
echo "kubeuser:kubeadmin" | chpasswd
usermod -aG sudo kubeuser

# Configure Firewall
# Firewall rules to help protect the server from unauthorized access while allowing necessary traffic.
echo "[TASK 10] Configure firewall"
ufw allow OpenSSH
ufw allow 6443   # Kubernetes API server port
ufw enable

# Enable IP Forwarding
# Essential for routing traffic between pods and external networks.
echo "[TASK 11] Enable IP forwarding"
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

echo "[TASK 7] Install Kubernetes components"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubeadm=1.28.1-1.1 kubelet=1.28.1-1.1 kubectl=1.28.1-1.1


# Final message
OB
echo "[TASK 8] Bootstrap script completed. Please run 'kubeadm init' to initialize your Kubernetes cluster."
