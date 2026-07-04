variable "environment" {
  type        = string
  description = "Deployment environment"
  default     = "dev"
}

variable "location" {
  type        = string
  description = "Azure region"
  default     = "eastus"
}

variable "project_name" {
  type        = string
  description = "Project name used in resource naming"
  default     = "library"
}

variable "resource_group_name" {
  type        = string
  description = "Existing resource group name. If empty, a new RG is created"
  default     = ""
}

# AKS
variable "aks_node_count" {
  type        = number
  description = "Number of nodes in the default AKS node pool"
  default     = 1
}

variable "aks_vm_size" {
  type        = string
  description = "VM size for the AKS default node pool"
  default     = "Standard_B2s"
}

# ACR
variable "acr_sku" {
  type        = string
  description = "SKU for Azure Container Registry"
  default     = "Basic"
}

# Jenkins VM
variable "jenkins_vm_size" {
  type        = string
  description = "VM size for the Jenkins server"
  default     = "Standard_B2s"
}

variable "admin_username" {
  type        = string
  description = "Admin username for the Jenkins VM"
  default     = "azureuser"
}

variable "admin_password" {
  type        = string
  description = "Admin password for the Jenkins VM"
  sensitive   = true
}
