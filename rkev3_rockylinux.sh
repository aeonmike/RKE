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



# INFORMATION #
#SystemdCgroup is a systemd feature used for controlling and managing processes in Linux systems. 
#In particular, it's related to systemd's #integration with cgroups (Control Groups)
#which is a Linux kernel feature that allows for the #organization and management of processes #into hierarchical groups, providing #resource isolation and control.

#Edit Containerd Parameters for Compatibility to K8

{
echo "Find the SystemdCgroup field and change its value to true"
echo "SystemdCgroup = true"
sleep 10s
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
cat <<EOF | sudo tee /etc/yum.repos.d/k8s.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

dnf repolist
dnf -y install kubectl
}


