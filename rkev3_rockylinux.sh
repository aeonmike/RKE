#!/bin/bash
#Mike cabalin - Aeonmike
#Cluster Config k8 RL 9
# Version 3

{
swapoff -a
sed -i '/ swap / s/^(.*)$/#\1/g' /etc/fstab
}


{
mkdir /root/backupconfig
sudo mv /etc/containerd/config.toml /root/backupconfig
cd /root
containerd config default > config.toml
}



#INFORMATION
#SystemdCgroup is a systemd feature used for controlling and managing processes in Linux systems. Providing resource isolation and #control.

#Edit Containerd Parameters for Compatibility to K8

{
echo "Find the SystemdCgroup field and change its value to true"
echo "SystemdCgroup = true"
sleep 2s
}

#Edit Config

{
nano config.toml
}

#Move and Enable Containerd Service
{
mv config.toml /etc/containerd/config.toml
systemctl enable --now containerd.service
}

#Add k8 Parameters for Network Overlay

{
echo "overlay" >> /etc/modules-load.d/k8s.conf
echo "br_filter" >> /etc/modules-load.d/k8s.conf
modprobe overlay
modprobe br_filter
}

{


#Add k8 Network Parameters

{
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/k8s.conf
echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.d/k8s.conf
echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.d/k8s.conf
sysctl --system
}


#Add k8 repo

{

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
EOF

dnf repolist
dnf -y install kubectl
}
