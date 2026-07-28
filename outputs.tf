output "resource_group_name" {
  description = "Resource group containing the VM."
  value       = azurerm_resource_group.this.name
}

output "public_ip_address" {
  description = "Public IPv4 address of the VM."
  value       = azurerm_public_ip.this.ip_address
}

output "ssh_command" {
  description = "Command used to connect to the VM."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.this.ip_address}"
}
