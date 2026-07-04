output "public_ip" {
  description = "Public IP address of the Jenkins VM"
  value       = azurerm_public_ip.jenkins.ip_address
}

output "fqdn" {
  description = "FQDN of the Jenkins VM"
  value       = azurerm_public_ip.jenkins.fqdn
}

output "vm_id" {
  description = "ID of the Jenkins VM"
  value       = azurerm_linux_virtual_machine.jenkins.id
}
