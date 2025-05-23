#!/bin/bash

# Exit on error
set -e

echo "======================"
echo "Setup"
echo "======================"

# Function to install a package if not already installed
install_package() {
    local package_name=$1
    echo "Checking for $package_name..."
    
    if ! command -v $package_name &> /dev/null; then
        echo "$package_name not found, installing..."
        # Try apt-get (Debian/Ubuntu)
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y $package_name
        else
            echo "Cannot install $package_name automatically. Please install $package_name manually and try again."
            exit 1
        fi
    else
        echo "$package_name is already installed: $(which $package_name)"
    fi
}

# Install prerequisites
echo "Checking for prerequisites..."
install_package curl
install_package git
install_package gpg

# Check architecture
ARCH=$(uname -m)
echo "Architecture: $ARCH"

if [ "$ARCH" != "x86_64" ]; then
  echo "Warning: This script is designed for x86_64/amd64 architecture."
  echo "Your architecture is $ARCH, which might not work correctly."
  read -p "Do you want to continue anyway? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Install docker
echo "Installing docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli
sudo systemctl enable docker
sudo systemctl start docker

# Install docker-compose
echo "Installing docker-compose..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install k3s
echo "Installing k3s..."
curl -sfL https://get.k3s.io | sudo sh -s - --write-kubeconfig-mode 644

# Set KUBECONFIG environment variable
echo "Setting KUBECONFIG environment variable..."
KUBECONFIG_LINE='export KUBECONFIG=/etc/rancher/k3s/k3s.yaml'
grep -qF "$KUBECONFIG_LINE" ~/.bashrc || echo "$KUBECONFIG_LINE" >> ~/.bashrc
grep -qF "$KUBECONFIG_LINE" ~/.zshrc 2>/dev/null || echo "$KUBECONFIG_LINE" >> ~/.zshrc 2>/dev/null

# Export the variable for the current session
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Install kubectl (k3s already includes it, but installing separately to be sure)
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

# Test kubectl
echo "Testing kubectl..."
kubectl get nodes

# Install k9s
echo "Installing k9s..."
K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
curl -LO "https://github.com/derailed/k9s/releases/download/$K9S_VERSION/k9s_Linux_amd64.tar.gz"
tar -zxvf k9s_Linux_amd64.tar.gz
sudo mv k9s /usr/local/bin/
rm k9s_Linux_amd64.tar.gz

# Install helm
echo "Installing helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install terraform
echo "Installing terraform..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update
sudo apt-get install terraform

# Install argocd
echo "Installing argocd..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd

# Print success message
echo "========================================"
echo "Installation Complete!"
echo "========================================"
echo "k3s, kubectl, k9s, helm, terraform, docker, docker-compose are now installed."
echo "You may need to restart your shell or run the following command to use kubectl:"
echo "  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
echo "  source ~/.bashrc"
echo "To verify the installation, run:"
echo "  docker --version"
echo "  docker-compose --version"
echo "  k3s --version"
echo "  kubectl get nodes"
echo "  k9s --version"
echo "  helm version"
echo "  terraform version"
echo "========================================" 