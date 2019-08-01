provider "azurerm" { version = "~> 1.32" }
provider "random" { version = "~> 2.1" }
provider "local" { version = "~> 1.3" }
provider "template" { version = "~> 2.1" }
provider "null" { version = "~> 2.1" }

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
  count               = length(var.vm_configuration)
  name                = "${lookup(var.vm_configuration[count.index], "vnet_name")}"
  address_space       = ["${lookup(var.vm_configuration[count.index], "vnet_address_space")}"]
  location            = "${lookup(var.vm_configuration[count.index], "location")}"
  resource_group_name = "${var.default_resource_group_name}"
}

# Create subnet
resource "azurerm_subnet" "myterraformsubnet" {
  count                = length(azurerm_virtual_network.myterraformnetwork)
  name                 = "${lookup(azurerm_virtual_network.myterraformnetwork[count.index], "name")}_subnet"
  resource_group_name  = "${var.default_resource_group_name}"
  virtual_network_name = "${lookup(azurerm_virtual_network.myterraformnetwork[count.index], "name")}"
  address_prefix       = "${lookup(var.vm_configuration[count.index], "subnet_address_prefix")}"
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
  count               = length(var.vm_configuration)
  name                = "${lookup(var.vm_configuration[count.index], "name")}-publicIP"
  location            = "${lookup(var.vm_configuration[count.index], "location")}"
  resource_group_name = "${var.default_resource_group_name}"
  allocation_method   = "Dynamic"
  domain_name_label   = "${lookup(var.vm_configuration[count.index], "name")}-${var.domain_name_label}"
}

# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
  count               = length(var.vm_configuration)
  name                = "${lookup(var.vm_configuration[count.index], "name")}-NIC"
  location            = "${lookup(var.vm_configuration[count.index], "location")}"
  resource_group_name = "${var.default_resource_group_name}"

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = "${lookup(azurerm_subnet.myterraformsubnet[count.index], "id")}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.myterraformpublicip[count.index].id}"
  }
}

resource "random_string" "password" {
  length  = 16
  special = true
}

# Create virtual machines
resource "azurerm_virtual_machine" "myterraformvm" {
  count                         = length(var.vm_configuration)
  name                          = "${lookup(var.vm_configuration[count.index], "name")}-VM"
  location                      = "${lookup(var.vm_configuration[count.index], "location")}"
  resource_group_name           = "${var.default_resource_group_name}"
  network_interface_ids         = ["${azurerm_network_interface.myterraformnic[count.index].id}"]
  vm_size                       = "${lookup(var.vm_configuration[count.index], "vm_size")}"
  delete_os_disk_on_termination = true

  storage_os_disk {
    name              = "${lookup(var.vm_configuration[count.index], "name")}-disk"
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
    computer_name  = "${lookup(var.vm_configuration[count.index], "name")}-VM"
    admin_username = "${var.vm_user}"
    admin_password = "${random_string.password.result}"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = "${file(var.ssh_public_key)}"
    }
  }

  # Prepare Ansible runtime
  provisioner "remote-exec" {
    inline = [
      "sudo apt -y install python"
    ]

    connection {
      type        = "ssh"
      private_key = "${file(var.ssh_private_key)}"
      user        = "${var.vm_user}"
      host        = "${azurerm_public_ip.myterraformpublicip[count.index].fqdn}"
    }
  }
}

# ANSIBLE
# Create inventory file from template
data "template_file" "inventory_file" {
  template = "${file("./inventory_templates/hosts.tpl")}"
  vars = {
    ansible_user      = "${var.vm_user}"
    node_ip_addresses = "${join("\n", azurerm_public_ip.myterraformpublicip.*.fqdn)}"
  }
}

# Save inventory file
resource "local_file" "saveinventory" {
  content  = "${data.template_file.inventory_file.rendered}"
  filename = "./ansible/inventories/test/hosts"
}

# Execute playbook
resource "null_resource" "executeansible" {
  provisioner "local-exec" {
    command = "ansible-playbook ./ansible/site.yml -i ./ansible/inventories/test/hosts --private-key=${var.ssh_private_key}"
  }

  triggers = {
    "after" = "${join(",", azurerm_virtual_machine.myterraformvm.*.id)}"
  }
}

# Create Traffic Manager profile
resource "azurerm_traffic_manager_profile" "netcoreapp" {
  name                   = "netcoreapp-traffic-manager"
  resource_group_name    = "${var.default_resource_group_name}"
  traffic_routing_method = "Priority"

  dns_config {
    relative_name = "${var.domain_name_label}"
    ttl           = 100
  }

  monitor_config {
    protocol = "http"
    port     = 80
    path     = "/"
  }
}

# Create Traffic Manager endpoints (for each VM)
resource "azurerm_traffic_manager_endpoint" "endpoints" {
  count               = length(azurerm_public_ip.myterraformpublicip)
  name                = "${lookup(var.vm_configuration[count.index], "name")}-endpoint"
  resource_group_name = "${var.default_resource_group_name}"
  profile_name        = "${azurerm_traffic_manager_profile.netcoreapp.name}"
  target_resource_id  = "${azurerm_public_ip.myterraformpublicip[count.index].id}"
  type                = "azureEndpoints"
}
