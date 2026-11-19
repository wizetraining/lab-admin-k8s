#!/bin/bash

# L'authentification par mot de passe est désactivée par défaut et l'activer permet d'effectuer l'authentification par mot de passe.

# sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
sudo systemctl restart sshd

# Updating the hosts file for all the 3 nodes with the IP given in vagrantfile

# 10.10.10.10 controlplane.wizetraining.local controlplane
# 10.10.10.11 node1.wizetraining.local node1
# 10.10.10.12 node2.wizetraining.local node2
# 10.10.10.13 node3.wizetraining.local node3

sudo echo -e "10.10.10.10 controlplane.wizetraining.local controlplane\n10.10.10.11 node1.wizetraining.local node1\n10.10.10.12 node2.wizetraining.local node2\n10.10.10.13 node3.wizetraining.local node3" >> /etc/hosts

# Source: https://kubernetes.io/docs/reference/setup-tools/kubeadm

KUBE_VERSION=1.36.5

set -e


### verify Ubuntu version
source /etc/lsb-release
if [ "$DISTRIB_RELEASE" != "24.04" ]; then
    echo "################################# "
    echo "############ WARNING ############ "
    echo "################################# "
    echo
    echo "This script only works on Ubuntu 24.04!"
    echo "You're using: ${DISTRIB_DESCRIPTION}"
    echo "Better ABORT with Ctrl+C. Or press any key to continue the install"
    read
fi


### get platform
PLATFORM=`uname -p`

if [ "${PLATFORM}" == "aarch64" ]; then
  PLATFORM="arm64"
elif [ "${PLATFORM}" == "x86_64" ]; then
  PLATFORM="amd64"
else
  echo "${PLATFORM} has to be either amd64 or arm64/aarch64. Check containerd supported binaries page"
  echo "https://github.com/containerd/containerd/blob/main/docs/getting-started.md#option-1-from-the-official-binaries"
  exit 1
fi


### set hostname to the first part before the first dot
short_hostname=$(hostname | cut -d. -f1)
hostnamectl set-hostname "$short_hostname"


### setup terminal
apt-get --allow-unauthenticated update
apt-get --allow-unauthenticated install -y bash-completion binutils
echo 'colorscheme ron' >> ~/.vimrc
echo 'set tabstop=2' >> ~/.vimrc
echo 'set shiftwidth=2' >> ~/.vimrc
echo 'set expandtab' >> ~/.vimrc
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'alias c=clear' >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc
sed -i '1s/^/force_color_prompt=yes\n/' ~/.bashrc


### disable linux swap and remove any existing swap partitions
swapoff -a
sed -i '/\sswap\s/ s/^\(.*\)$/#\1/g' /etc/fstab


### remove packages
kubeadm reset -f || true
crictl rm --force $(crictl ps -a -q) || true
apt-mark unhold kubelet kubeadm kubectl kubernetes-cni || true
apt-get remove -y docker.io containerd kubelet kubeadm kubectl kubernetes-cni || true
apt-get autoremove -y
systemctl daemon-reload

### k8s
apt-get update
apt-get install -y apt-transport-https ca-certificates
mkdir -p /etc/apt/keyrings
rm /etc/apt/keyrings/kubernetes-1-36-apt-keyring.gpg || true
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-1-36-apt-keyring.gpg
echo > /etc/apt/sources.list.d/kubernetes.list
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-1-36-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
apt-get --allow-unauthenticated update
apt-get --allow-unauthenticated install -y containerd kubelet=${KUBE_VERSION}-1.1 kubeadm=${KUBE_VERSION}-1.1 kubectl=${KUBE_VERSION}-1.1 kubernetes-cni

### configure containerd
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system
sudo mkdir -p /etc/containerd

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

# Cgroup driver systemd 
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

### crictl uses containerd as default
{
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
EOF
}

### disable appamor
aa-teardown > /dev/null 2>&1 || true
service apparmor stop > /dev/null 2>&1 || true
systemctl disable appamor > /dev/null 2>&1 || true
apt-get remove -y apparmor > /dev/null 2>&1 || true


### start services
systemctl daemon-reload
systemctl enable containerd
systemctl restart containerd
systemctl enable kubelet && systemctl start kubelet