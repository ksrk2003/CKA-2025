#!/bin/bash

set -euo pipefail

KUBERNETES_VERSION="v1.32"
CRIO_VERSION="v1.32"

echo -e "\n\033[1;34m==== Disabling Swap ====\033[0m"
sudo swapoff -a
sudo sed -i.bak '/ swap /s/^/#/' /etc/fstab

echo -e "\n\033[1;34m==== Installing Required Packages ====\033[0m"
sudo apt-get update -y
sudo apt-get install -y curl ca-certificates gnupg lsb-release software-properties-common

echo -e "\n\033[1;34m==== Trusting pkgs.k8s.io Certificate Chain ====\033[0m"
CERT_CHAIN="/usr/local/share/ca-certificates/pkgs_k8s_io.crt"
echo | openssl s_client -showcerts -connect pkgs.k8s.io:443 -servername pkgs.k8s.io 2>/dev/null | \
awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/ { print $0; if (/END CERTIFICATE/) print "" }' | \
sudo tee "$CERT_CHAIN" > /dev/null

sudo update-ca-certificates

echo -e "\n\033[1;34m==== Setting Up GPG Keyrings (with --insecure) ====\033[0m"
sudo mkdir -p /etc/apt/keyrings
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo rm -f /etc/apt/keyrings/cri-o-apt-keyring.gpg

curl -fsSL --insecure https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

curl -fsSL --insecure https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo -e "\n\033[1;34m==== Adding APT Repositories ====\033[0m"
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/cri-o.list

echo -e "\n\033[1;34m==== Installing Kubernetes & CRI-O Packages ====\033[0m"
sudo apt-get update -y
sudo apt-get install -y cri-o cri-tools kubelet kubeadm kubectl

echo -e "\n\033[1;34m==== Enabling & Starting CRI-O ====\033[0m"
sudo systemctl daemon-reexec
sudo systemctl enable crio.service
sudo systemctl start crio.service

echo -e "\n\033[1;34m==== Configuring Networking Kernel Modules ====\033[0m"
sudo modprobe br_netfilter
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/k8s.conf
echo 'net.bridge.bridge-nf-call-iptables=1' | sudo tee -a /etc/sysctl.d/k8s.conf
echo 'net.bridge.bridge-nf-call-ip6tables=1' | sudo tee -a /etc/sysctl.d/k8s.conf
sudo sysctl --system

echo -e "\n\033[1;32m##################################################"
echo -e "############## INSTALLATION COMPLETE ############"
echo -e "##################################################\033[0m"

echo -e "\n\033[1;33mOn the control-plane node, run this to get the join command:\033[0m"
echo -e "\n  \033[1;36mkubeadm token create --print-join-command\033[0m\n"
