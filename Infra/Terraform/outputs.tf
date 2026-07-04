output "resource_group_name" {
  description = "Name of the resource group"
  value       = local.rg_name
}

# ACR
output "acr_login_server" {
  description = "ACR login server URL"
  value       = module.acr.login_server
}

output "acr_name" {
  description = "ACR name"
  value       = module.acr.acr_name
}

# AKS
output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.cluster_name
}

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = module.aks.cluster_id
}

# Jenkins
output "jenkins_public_ip" {
  description = "Public IP of the Jenkins VM"
  value       = module.jenkins.public_ip
}

output "jenkins_fqdn" {
  description = "FQDN of the Jenkins VM"
  value       = module.jenkins.fqdn
}
