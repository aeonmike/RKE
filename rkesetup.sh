#!/bin/bash
#AeonMike - DevOps Engr. Batch 1
#RKE Cluster Setup script
#Run this script on the cluster member from master to worker nodes to automate plugins installation and readiness check
#DevSecOPS Academe Batch 1

# Enable ssh password authentication

echo "Enable SSH password authentication:"
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
systemctl reload sshd

# Set Root password
echo "Adding root password using: Devsecops#2023"
echo "Set root password:"
echo -e "Devsecops#2023\nDevsecops#2023" | passwd root >/dev/null 2>&1

# Commands for all K8s nodes
# Add Docker GPG key, Docker Repo, install Docker and enable services
# Add repo and Install packages
echo 'Running System Update'
{
sudo apt update
sudo apt -y full-upgrade
[ -f /var/run/reboot-required ] && sudo reboot -f
}

#Adding hostname entry

echo 'Adding hostname entry'
sudo tee /etc/hosts << EOF
172.16.16.172   master.devsecops-academe.com  master
172.16.16.174   worker1.devsecops-academe.com worker1
172.16.16.175   worker2.devsecops-academe.com worker2
EOF

sleep 5s
#Install Docker and Containerd

{
sudo apt update
sudo apt install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
apt-cache policy docker-ce
sudo apt install docker-ce=5:20.10.24~3-0~ubuntu-focal containerd.io docker-ce-cli
}

#Setting docker parameters
cat <<EOF | sudo tee /etc/docker/daemon.json
{
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

sleep 5s

echo 'Start and enable Services'
sudo systemctl daemon-reload 
sudo systemctl enable docker
sudo systemctl start docker

#Configure containerd and start service

echo 'Configure containerd and start service'
mkdir -p /etc/containerd
containerd config default>/etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd


#Confirm that docker group has been created on system
sudo groupadd docker

# Add your current system user to the Docker group
sudo gpasswd -a $USER docker
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
echo 'Add apt repository for Kubernetes'

{
sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/kubernetes-xenial.gpg
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
}

#Note: At time of writing this guide, Xenial is the latest Kubernetes repository but when repository is available for Ubuntu 22.04 (Jammy Jellyfish) then you need replace xenial word with ‘jammy’ in ‘apt-add-repository’ command
#Install Kubernetes components Kubectl, kubeadm & kubelet
#Install Kubernetes components like kubectl, kubelet and Kubeadm utility on all the nodes. Run following set of commands,

echo 'Installing kubelet system manager'

{
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
}

sleep 2s

sudo tee /etc/default/kubelet <<EOF
KUBELET_EXTRA_ARGS="--cgroup-driver=cgroupfs"
EOF

sleep 2s
echo Environment="KUBELET_EXTRA_ARGS=--fail-swap-on=false" >> /etc/systemd/system/kubelet.service.d/10-kubeadm.conf


#Checking all plugins and packages are OK

echo 'Checking all plugins and packages are OK'

STATUS="$(systemctl is-active docker)"
if [ "${STATUS}" = "active" ]; then
    echo "Docker - OK Installed"
else 
    echo " Service not running.... so exiting "  
    exit 1  
fi

STATUS="$(systemctl is-active containerd)"
if [ "${STATUS}" = "active" ]; then
    echo "Containerd - OK Installed"
else 
    echo " Service not running.... so exiting "  
    exit 1  
fi

sleep 20s

exit
