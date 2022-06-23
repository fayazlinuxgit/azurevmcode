
output "resource_group_name" {
  value = azurerm_resource_group.fayaz-res-group.name
}

output "public_ip_address" {
  value = azurerm_linux_virtual_machine.myvm-test.public_ip_address
}

output "tls_private_key" {
  value     = tls_private_key.fayaz_ssh.private_key_pem
  sensitive = true
}