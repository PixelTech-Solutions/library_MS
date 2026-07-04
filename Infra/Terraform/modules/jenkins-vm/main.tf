# --- Networking ---
resource "azurerm_virtual_network" "jenkins" {
  name                = "vnet-jenkins-${var.project_name}-${var.environment}"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_subnet" "jenkins" {
  name                 = "snet-jenkins"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.jenkins.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "jenkins" {
  name                = "pip-jenkins-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "jenkins-${var.project_name}-${var.environment}"

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_network_security_group" "jenkins" {
  name                = "nsg-jenkins-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Jenkins-Web"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Jenkins-Agent"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "50000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_network_interface" "jenkins" {
  name                = "nic-jenkins-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.jenkins.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jenkins.id
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_network_interface_security_group_association" "jenkins" {
  network_interface_id      = azurerm_network_interface.jenkins.id
  network_security_group_id = azurerm_network_security_group.jenkins.id
}

# --- Jenkins VM ---
resource "azurerm_linux_virtual_machine" "jenkins" {
  name                            = "vm-jenkins-${var.project_name}-${var.environment}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.jenkins.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOF
#!/bin/bash
set -e

# Update system
apt-get update -y
apt-get upgrade -y

# Install Java 17 (required for Jenkins)
apt-get install -y openjdk-17-jdk

# Install Jenkins
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null
apt-get update -y
apt-get install -y jenkins

# Install Docker
apt-get install -y ca-certificates curl gnupg lsb-release
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Install docker-compose (standalone)
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Add jenkins user to docker group
usermod -aG docker jenkins

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install Maven
apt-get install -y maven

# Install Jenkins plugins (JCasC, pipeline, docker, git, credentials)
mkdir -p /var/lib/jenkins/plugins
PLUGIN_URL="https://updates.jenkins.io/latest"
for plugin in configuration-as-code workflow-aggregator docker-workflow git credentials-binding pipeline-stage-view; do
  curl -fsSL "$PLUGIN_URL/$plugin.hpi" -o "/var/lib/jenkins/plugins/$plugin.hpi"
done
chown -R jenkins:jenkins /var/lib/jenkins/plugins

# Jenkins Configuration as Code — auto-creates the library pipeline job
mkdir -p /var/lib/jenkins/casc_configs
cat > /var/lib/jenkins/casc_configs/jobs.yaml << 'CASC'
jenkins:
  systemMessage: "Jenkins configured via Terraform IaC"
jobs:
  - script: |
      pipelineJob('library-management-deploy') {
        description('Build & Deploy Library Management App to AKS')
        definition {
          cpsScm {
            scm {
              git {
                remote {
                  url('https://github.com/PixelTech-Solutions/library_MS.git')
                }
                branches('*/main')
              }
            }
            scriptPath('Jenkinsfile')
            lightweight(true)
          }
        }
        triggers {
          githubPush()
        }
      }
CASC
chown -R jenkins:jenkins /var/lib/jenkins/casc_configs

# Tell Jenkins to use JCasC
echo 'JAVA_ARGS="-Dcasc.jenkins.config=/var/lib/jenkins/casc_configs"' >> /etc/default/jenkins

# Start and enable services
systemctl enable jenkins
systemctl start jenkins
systemctl enable docker
systemctl start docker
EOF
  )

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}
