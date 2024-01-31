#!/bin/bash
#Ubuntu 20.04
#AWS Support

apt update -y

#Disable swap & firewall


{
ufw disable
sudo systemctl disable ufw
sudo systemctl stop ufw
sudo systemctl disable apparmor
sudo systemctl stop apparmor
swapoff -a; sed -i '/swap/d' /etc/fstab
}


#Adding hostname entry

echo 'Adding hostname entry'
sudo tee /etc/hosts << EOF
192.168.100.50   master.devsecops-academe.com  master
192.168.100.51   worker1.devsecops-academe.com worker1
192.168.100.52   worker2.devsecops-academe.com worker2
EOF

#Update sysctl settings for Kubernetes networking
{

cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

}

sleep 3s

#Install docker engine
{
apt install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update && apt install -y docker-ce=5:19.03.10~3-0~ubuntu-focal docker-ce-cli=5:19.03.10~3-0~ubuntu-focal containerd.io
}


#Confirm that docker group has been created on system
# Add your current system user to the Docker group

{
sudo groupadd docker
usermod -aG docker root
sudo gpasswd -a $USER docker
sudo usermod -aG docker $USER
clear
docker --version
}


# Start and enable Services

sleep 5s

{
echo 'Start and enable Services'
sudo systemctl daemon-reload 
sudo systemctl enable docker
sudo systemctl start docker
}

sleep 3s

# Modify bridge adapter setting
# Configure sysctl.
{
sudo modprobe overlay
sudo modprobe br_netfilter
}


{
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
sleep 5s
}

# Ensure that the br_netfilter module is loaded


lsmod | grep br_netfilter
lsmod | grep overlay

#Add apt repository for Kubernetes
#Execute following commands to add apt repository for Kubernetes

sleep 5s

echo 'Add apt repository for Kubernetes'

{
sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/kubernetes-xenial.gpg
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
}


echo 'Installing kubelet system manager'

{
sudo apt update -y
sudo apt install -y kubelet kubectl kubeadm
sudo apt-mark hold kubelet kubectl kubeadm
}

sleep 2s

{
sudo tee /etc/default/kubelet <<EOF
KUBELET_EXTRA_ARGS="--cgroup-driver=cgroupfs"
EOF

sleep 2s
echo Environment="KUBELET_EXTRA_ARGS=--fail-swap-on=false" >> /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
}

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

sleep 5s

exit
