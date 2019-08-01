output "traffic_manager" {
  value = azurerm_traffic_manager_profile.netcoreapp.fqdn
}

output "public_ips" {
  value = azurerm_public_ip.myterraformpublicip
}

output "vm_configs" {
  value = azurerm_virtual_machine.myterraformvm
}