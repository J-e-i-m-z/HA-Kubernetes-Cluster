# Setting up a Highly Available Kubernetes Cluster using kubeadm

- This project involves setting up a highly available (HA) Kubernetes cluster using kubeadm designed for performance, security, and reliability. 
- The implementation features three Kubernetes master nodes for redundancy, two worker nodes for workload distribution, 
- I also implementedHAProxy and two load balancers to ensures traffic is efficiently managed, enhancing the cluster's availability.
- The project SHOULD also have monitoring tools for cluster health, and centralized logging for effective troubleshooting.

# Document overview
- This project is command-intensive, focusing on a series of configurations and setups essential for building a high-availability Kubernetes cluster. I have endeavored to include all relevant commands throughout the documentation.

## Implemented Architecture
- The implemented architecture consists of:

1. Master Nodes: Three master nodes configured for high availability.
2. Worker Nodes: Two worker nodes to handle application workloads.
3. Load Balancers: Two load balancers to distribute traffic and manage failover.

## Set Up
- In this project the servers run on virtual machines configured in a vagrant file. Despite the many advantages of using the cloud,  I chose this approach to avoid incurring cloud usage costs
- The vagrant file is included in my repository in the HA_K8S_Project folder.

## Enhancing Server Security: SSH Configuration
- The code snippet below, available in the Vagrantfile is aimed at enhancing the security of a server by modifying its SSH (Secure Shell) configuration
1. Disable Root Login
```bash
sed -i 's/^PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
```
- Disabling root login prevents unauthorized users from accessing the server directly as the root user, which is the most powerful account on the system. By eliminating this method of access, the risk of brute-force attacks targeting the root account is significantly reduced, enhancing overall system security.

2. Disable Password Authentication
```bash
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
```
- By requiring SSH keys for authentication instead of passwords, this measure increases security. SSH keys are more difficult to brute-force than passwords, and they also eliminate the risk of password theft

## Virtual IP managed by Keepalived on the load balancer nodes
- A VIP is an IP address that is not tied to a specific physical network interface. Instead, it can float between different servers (in this case, load balancers).
- Keepalived monitors the health of load balancer nodes and manages the VIP. It uses the Virtual Router Redundancy Protocol (VRRP) to ensure that one node is always the active primary node, while others can take over if the primary node fails

## Why I used HAproxy
- HAProxy efficiently distributes incoming network traffic across multiple servers or nodes. This helps to balance the load, ensuring no single server is overwhelmed, which can lead to better performance and reliability.

## Why I used both HAProxy and Loadbalancers 
- Both HAProxy and dedicated load balancers were used to improve redundancy. If one component fails, the other can take over, ensuring that the services remain accessible. If the dedicated load balancer fails, HAProxy can still manage traffic to the backend services.


## Pre-requisites
* Virtualbox installed
* Vagrant installed

## Bringing up all the virtual machines
```
vagrant up
```
## Set up load balancer nodes (loadbalancer1 & loadbalancer2)
##### Install Keepalived & Haproxy
```
apt update && apt install -y keepalived haproxy
```
##### configure keepalived
On both nodes create the health check script /etc/keepalived/check_apiserver.sh
```
cat >> /etc/keepalived/check_apiserver.sh <<EOF
#!/bin/sh

errorExit() {
  echo "*** $@" 1>&2
  exit 1
}

curl --silent --max-time 2 --insecure https://localhost:6443/ -o /dev/null || errorExit "Error GET https://localhost:6443/"
if ip addr | grep -q 172.16.16.100; then
  curl --silent --max-time 2 --insecure https://172.16.16.100:6443/ -o /dev/null || errorExit "Error GET https://172.16.16.100:6443/"
fi
EOF

chmod +x /etc/keepalived/check_apiserver.sh
```
Create keepalived config /etc/keepalived/keepalived.conf
```
cat >> /etc/keepalived/keepalived.conf <<EOF
vrrp_script check_apiserver {
  script "/etc/keepalived/check_apiserver.sh"
  interval 3
  timeout 10
  fall 5
  rise 2
  weight -2
}

vrrp_instance VI_1 {
    state BACKUP
    interface eth1
    virtual_router_id 1
    priority 100
    advert_int 5
    authentication {
        auth_type PASS
        auth_pass mysecret
    }
    virtual_ipaddress {
        172.16.16.100
    }
    track_script {
        check_apiserver
    }
}
EOF
```
##### Enable & start keepalived service
```
systemctl enable --now keepalived
```

##### Configure haproxy
Update **/etc/haproxy/haproxy.cfg**
```
cat >> /etc/haproxy/haproxy.cfg <<EOF

frontend kubernetes-frontend
  bind *:6443
  mode tcp
  option tcplog
  default_backend kubernetes-backend

backend kubernetes-backend
  option httpchk GET /healthz
  http-check expect status 200
  mode tcp
  option ssl-hello-chk
  balance roundrobin
    server kmaster1 172.16.16.101:6443 check fall 3 rise 2
    server kmaster2 172.16.16.102:6443 check fall 3 rise 2
    server kmaster3 172.16.16.103:6443 check fall 3 rise 2

EOF
```
##### Enable & restart haproxy service
```
systemctl enable haproxy && systemctl restart haproxy
```
## Pre-requisites on all kubernetes nodes (masters & workers)
##### Disable swap
- Disabling swap enhances performance stability. Kubernetes relies heavily on the availability of memory resources for optimal performance. When swap is enabled, the Linux kernel may move processes in and out of RAM to swap space on disk, which can lead to increased latency and unpredictable performance.
In a containerized environment, this can result in poor application performance, as the container may become slow or unresponsive due to the delay in accessing swapped-out data.
```
swapoff -a; sed -i '/swap/d' /etc/fstab
```
##### Disable Firewall
- Despite initial security configurations, I disabled firewall simplify networking and ensure that all components can communicate without being blocked by firewall rules. 

```
systemctl disable --now ufw
```
##### Enable and Load Kernel modules
- The code snippet below is aimed at enabling and loading specific kernel modules required for containerization, particularly when using containerd container runtime which is used in this project.
```
{
cat >> /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter
}
```
##### Add Kernel settings
```
{
cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system
}
```
##### Install containerd runtime
- Containerd is the default container runtime for Kubernetes. It integrates well with Kubernetes through the Container Runtime Interface (CRI). This makes it an ideal choice for Kubernetes clusters, as it eliminates the need for Docker's additional features and complexities.
```
{
  apt update
  apt install -y containerd apt-transport-https
  mkdir /etc/containerd
  containerd config default > /etc/containerd/config.toml
  systemctl restart containerd
  systemctl enable containerd
}
```
##### Add apt repo for kubernetes
```
{
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
  apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
}
```
##### Install Kubernetes components
- Kubeadm simplifies the process of setting up a cluster by automating the installation and configuration of essential components.
- Kubelet is responsible for managing the lifecycle of containers, ensuring that they are running and healthy according to the desired state specified in the Kubernetes API.
- Kubectl is a command-line interface for interacting with Kubernetes clusters.
```
{
  apt update
  apt install -y kubeadm=1.22.0-00 kubelet=1.22.0-00 kubectl=1.22.0-00
}
```
## Bootstrap the cluster
## On kmaster1
##### Initialize Kubernetes Cluster
```
kubeadm init --control-plane-endpoint="172.16.16.100:6443" --upload-certs --apiserver-advertise-address=172.16.16.101 --pod-network-cidr=192.168.0.0/16
```
##### Deploy Calico network
- Calico is designed for performance, capable of handling high volumes of network traffic with minimal latency. This is particularly important in production environments where performance is a key concern.
```
kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f https://docs.projectcalico.org/v3.18/manifests/calico.yaml
```

## Join other master nodes to the cluster
> Respective kubeadm commands copied from the output of kubeadm init command on the first master were used here.

> --apiserver-advertise-address option is mandatory to the join command when joining the other master nodes.

## Join worker nodes to the cluster
> The kubeadm join command copied from the output of kubeadm init command on the first master was used here


## Downloading kube config to your local machine
On your host machine
```
mkdir ~/.kube
scp root@172.16.16.101:/etc/kubernetes/admin.conf ~/.kube/config
```
Password for root account is kubeadmin (if you used my Vagrant setup)

## Verifying the cluster
```
kubectl cluster-info
kubectl get nodes
```
## Monitoring setup for all the servers and Centralized log server 
- In the scope of this project, I have not included the implementation of a monitoring setup for all servers and a centralized log server.
- While the absence of a monitoring setup and centralized logging server limits operational visibility, this project serves as a foundation for future enhancements.
- I intend to build upon this base, integrating these critical components to achieve a fully-fledged, production-ready Kubernetes cluster.
- Robust monitoring solutions (e.g., Prometheus, Grafana) and centralized logging tool (ELK Stack) will be used.