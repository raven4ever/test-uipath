terraform {
  required_version = "> 0.12.0"
  required_providers {
    azurerm  = "~> 1.32"
    random   = "~> 2.1"
    local    = "~> 1.3"
    template = "~> 2.1"
    null     = "~> 2.1"
  }
}

# Create a virtual network for each of the zones
resource "azurerm_virtual_network" "tf_vnetwork" {
  count               = length(var.vm_configuration)
  name                = var.vm_configuration[count.index].network.name
  address_space       = [var.vm_configuration[count.index].network.vnet_address_space]
  location            = var.vm_configuration[count.index].location
  resource_group_name = var.default_resource_group_name
}

resource "azurerm_subnet" "tf_subnet" {
  count                = length(var.vm_configuration)
  name                 = var.vm_configuration[count.index].network.subnet_name
  resource_group_name  = var.default_resource_group_name
  virtual_network_name = azurerm_virtual_network.tf_vnetwork[count.index].name
  address_prefix       = var.vm_configuration[count.index].network.subnet_address_prefix
}

# Create public IPs for each defined VM and attach DNS label
resource "azurerm_public_ip" "tf_public_ip" {
  count               = length(var.vm_configuration)
  name                = "${var.vm_configuration[count.index].name}-publicIP"
  location            = var.vm_configuration[count.index].location
  resource_group_name = var.default_resource_group_name
  allocation_method   = "Dynamic"
  domain_name_label   = "${var.vm_configuration[count.index].name}${var.domain_name_label}"
}

# Create network interface
resource "azurerm_network_interface" "tf_nic" {
  count               = length(var.vm_configuration)
  name                = "${var.vm_configuration[count.index].name}-NIC"
  location            = var.vm_configuration[count.index].location
  resource_group_name = var.default_resource_group_name

  ip_configuration {
    name                          = "${var.vm_configuration[count.index].name}-NIC-config"
    subnet_id                     = azurerm_subnet.tf_subnet[count.index].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.tf_public_ip[count.index].id
  }
}

resource "random_string" "password" {
  count   = length(var.vm_configuration)
  length  = 19
  special = true
}

# Create virtual machines
resource "azurerm_virtual_machine" "tf_vm" {
  count                         = length(var.vm_configuration)
  name                          = "${var.vm_configuration[count.index].name}-VM"
  location                      = var.vm_configuration[count.index].location
  resource_group_name           = var.default_resource_group_name
  network_interface_ids         = [azurerm_network_interface.tf_nic[count.index].id]
  vm_size                       = var.vm_configuration[count.index].vm_size
  delete_os_disk_on_termination = true

  storage_os_disk {
    name              = "${var.vm_configuration[count.index].name}-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "${var.vm_configuration[count.index].name}-VM-name"
    admin_username = var.vm_user
    admin_password = random_string.password[count.index].result
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = file(var.ssh_public_key)
    }
  }

  # Prepare Ansible runtime
  provisioner "remote-exec" {
    inline = [
      "sudo apt -y install python"
    ]

    connection {
      type        = "ssh"
      private_key = file(var.ssh_private_key)
      user        = var.vm_user
      host        = azurerm_public_ip.tf_public_ip[count.index].fqdn
    }
  }
}

# ANSIBLE deployment
# Create inventory file from template
data "template_file" "create_inventory" {
  template = file("./inventory_templates/hosts.tpl")
  vars = {
    ansible_user      = var.vm_user
    node_ip_addresses = join("\n", azurerm_public_ip.tf_public_ip.*.fqdn)
  }
}

# Save inventory file
resource "local_file" "save_inventory" {
  content  = data.template_file.create_inventory.rendered
  filename = "./ansible/inventories/test/hosts"
}

# Execute playbook
resource "null_resource" "execute_ansible" {
  provisioner "local-exec" {
    command = "ansible-playbook ./ansible/site.yml -i ./ansible/inventories/test/hosts --private-key=${var.ssh_private_key}"
  }

  triggers = {
    "after" = join(",", azurerm_virtual_machine.tf_vm.*.id)
  }
}

# Create Traffic Manager profile
resource "azurerm_traffic_manager_profile" "tf_traffic_manager" {
  name                   = "netcoreapp-traffic-manager"
  resource_group_name    = var.default_resource_group_name
  traffic_routing_method = "Priority"

  dns_config {
    relative_name = var.domain_name_label
    ttl           = 100
  }

  monitor_config {
    protocol = "http"
    port     = 80
    path     = "/"
  }
}

# Create Traffic Manager endpoints (for each VM)
resource "azurerm_traffic_manager_endpoint" "tf_endpoints" {
  count               = length(azurerm_public_ip.tf_public_ip)
  name                = "${var.vm_configuration[count.index].name}-endpoint"
  resource_group_name = var.default_resource_group_name
  profile_name        = azurerm_traffic_manager_profile.tf_traffic_manager.name
  target_resource_id  = azurerm_public_ip.tf_public_ip[count.index].id
  type                = "azureEndpoints"
}

# Create send mail action
resource "azurerm_monitor_action_group" "sendmailaction" {
  name                = "SendMailAlertsAction"
  resource_group_name = var.default_resource_group_name
  short_name          = "p0action"

  dynamic "email_receiver" {
    for_each = var.mail_list
    content {
      name          = email_receiver.value.name
      email_address = email_receiver.value.email_address
    }
  }
}

/** Not working
# Create monitoring alert
resource "azurerm_monitor_metric_alert" "tf_endpoint_alert" {
  name                = "PrimaryEndpointMetricAlert"
  resource_group_name = var.default_resource_group_name
  scopes              = [azurerm_traffic_manager_profile.tf_traffic_manager.id]
  description         = "Action will be triggered when Endpoint metric in less than 1"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Network/trafficManagerProfiles"
    metric_name      = "Endpoint Status by Endpoint"
    operator         = "LessThan"
    threshold        = 1
    aggregation      = "Maximum"

    dimension {
      name     = "EndpointName"
      operator = "Include"
      values   = [azurerm_traffic_manager_endpoint.tf_endpoints[0].name]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.sendmailaction.id
  }
}
