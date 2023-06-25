#!/bin/bash
#AeonMike - DevOps Engr. Batch 1
#RKE Cluster Setup script
#Run this script on the cluster member from master to worker nodes to automate plugins installation and readiness check
#DevSecOPS Academe Batch 1
Grn='\033[0;32m'        # Green
Ylow='\033[0;33m'       # Yellow
Ble='\033[0;34m'         # Blue
NC='\033[0m' # No Color


# Enable ssh password authentication

echo -e "${Ylow}Enable SSH password authentication:"

sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
systemctl reload sshd

# Set Root password
echo -e "${Grn} Adding root password using: Devsecops#2023"
echo -e "${Grn} Setting root password:"
echo -e "Devsecops#2023\nDevsecops#2023" | passwd root >/dev/null 2>&1

sleep 10s

# Commands for all K8s nodes
# Add Docker GPG key, Docker Repo, install Docker and enable services
# Add repo and Install packages

echo -e "${Ylow}Running System Update${NC}"

{
sudo apt update
sudo apt -y full-upgrade
}

#Adding hostname entry

echo -e "${Ylow}Adding hostname entry${NC}"

sleep 2s
sudo tee /etc/hosts << EOF
127.0.0.1       localhost.localdomain            localhost
172.16.16.173   master.devsecops-academe.com     master
172.16.16.174   worker1.devsecops-academe.com    worker1
172.16.16.175   worker2.devsecops-academe.com    worker2
EOF

sleep 5s

#Install Utility tools

echo -e "${Ylow}Install utility tools${NC}"

sleep 2s

{
apt update
apt install git net-tools
git --version
}

sleep 2s

#Install RKE v1.3.3

echo -e "${Ylow}Install RKE v1.3.3${NC}"

sleep 2s

{
wget https://github.com/rancher/rke/releases/download/v1.3.3/rke_linux-amd64
chmod +x rke_linux-amd64
sudo mv rke_linux-amd64 /usr/local/bin/rke
which rke
rke --version
}


#Install Kubectl 1.21.14

echo -e "${Ylow} Install Kubectl 1.21.14${NC}"

sleep 2s

{
apt update -y
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" >> ~/kubernetes.list	
sudo mv ~/kubernetes.list /etc/apt/sources.list.d
sudo apt update
sudo apt-get install -y kubectl=1.21.14-00 
}


#Install Helm

echo -e "${Ylow} Install Helm Package Manager${NC}"

sleep 2s

{
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod +x get_helm.sh
./get_helm.sh
helm version
}

sleep 2s


#Install Docker V20.10 and Containerd

echo -e "${Ylow} Install Docker V20.10 and Containerd${NC}"

sleep 2s

{
sudo apt update
apt install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-cache policy docker-ce 
apt update && apt install -y docker-ce=5:20.10.0~3-0~ubuntu-focal docker-ce-cli=5:20.10.0~3-0~ubuntu-focal docker-ce-rootless-extras=5:20.10.0~3-0~ubuntu-focal containerd.io 
}


echo -e "${Ylow} Install Longhorn dependency${NC}"

{
sudo apt install nfs-common -y sudo 
systemctl enable iscsid 
}

sleep 2s


#Setting docker parameters


echo -e "${Ylow}Setting docker parameters${NC}"

sleep 2s

cat <<EOF | sudo tee /etc/docker/daemon.json
{
      "insecure-registries": ["localhost:5000"],
      "exec-opts": ["native.cgroupdriver=cgroupfs"],
      "log-driver": "json-file",
      "log-opts": {
      "max-size": "100m"
   },
       "storage-driver": "overlay2"
       }
EOF

sudo mkdir -p /etc/systemd/system/docker.service.d

# Start and enable Services

echo -e "${Ble} Start and enable Services${NC}"

sleep 5s

echo 'Start and enable Services'
sudo systemctl daemon-reload 
sudo systemctl enable docker
sudo systemctl start docker

#Configure containerd and start service

echo -e "${Ylow}Configure containerd and start service${NC}"

sleep 2s

mkdir -p /etc/containerd
containerd config default>/etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd


#Confirm that docker group has been created on system
sudo groupadd docker

# Add your current system user to the Docker group
sudo gpasswd -a $USER docker

echo -e "${Ylow}Checking Docker Version${NC}"
docker --version
sleep 10s

# Turn off swap
# The Kubernetes scheduler determines the best available node on 
# which to deploy newly created pods. If memory swapping is allowed 
# to occur on a host system, this can lead to performance and stability 
# issues within Kubernetes. 
# For this reason, Kubernetes requires that you disable swap in the host system.
# If swap is not disabled, kubelet service will not start on the masters and nodes


sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a

# Turn off firewall (Optional)
ufw disable

# Modify bridge adapter setting
# Configure sysctl.

sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

sleep 10s

# Ensure that the br_netfilter module is loaded

lsmod | grep br_netfilter

#Add apt repository for Kubernetes
#Execute following commands to add apt repository for Kubernetes

sleep 10s

clear

echo -e "${Ylow}Checking all plugins and packages are OK${NC}"

STATUS="$(systemctl is-active docker)"
if [ "${STATUS}" = "active" ]; then
    echo -e "${Grn}Docker - OK Installed"
else 
    echo " Service not running.... so exiting "  
    exit 1  
fi

STATUS="$(systemctl is-active containerd)"
if [ "${STATUS}" = "active" ]; then
    echo -e "${Grn}Containerd - OK Installed"
else 
    echo " Service not running.... so exiting "  
    exit 1  
fi

type -P rke &>/dev/null && echo -e "${Grn}RKE Found${NC}" || echo "Not Found"
type -P kubectl &>/dev/null && echo -e "${Grn}Kubectl Found${NC}" || echo "Not Found"

sleep 20s

exit
