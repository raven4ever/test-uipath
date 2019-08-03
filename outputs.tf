output "application_url" {
  value = azurerm_traffic_manager_profile.tf_traffic_manager.fqdn
}

data "template_file" "ssh_connections" {
  count    = length(var.vm_configuration)
  template = file("./tf_templates/ssh_connections.tpl")
  vars = {
    vm_user   = var.vm_user
    vm_fqdn   = azurerm_public_ip.tf_public_ip[count.index].fqdn
    vm_passwd = random_string.password[count.index].result
  }
}

output "rendered" {
  value = data.template_file.ssh_connections.*.rendered
}
