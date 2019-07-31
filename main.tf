provider "azurerm" {
  version = "~> 1.32"
}

provider "random" {
  version = "~> 2.1"
}

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

# Create virtual machine
resource "azurerm_virtual_machine" "myterraformvm" {
  count                 = length(var.vm_configuration)
  name                  = "${lookup(var.vm_configuration[count.index], "name")}-VM"
  location              = "${lookup(var.vm_configuration[count.index], "location")}"
  resource_group_name   = "${var.default_resource_group_name}"
  network_interface_ids = ["${azurerm_network_interface.myterraformnic[count.index].id}"]
  vm_size               = "${lookup(var.vm_configuration[count.index], "vm_size")}"

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
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = "${var.ssh_key}"
    }
  }
}

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

resource "azurerm_traffic_manager_endpoint" "endpoints" {
  count               = length(azurerm_public_ip.myterraformpublicip)
  name                = "${lookup(var.vm_configuration[count.index], "name")}-endpoint"
  resource_group_name = "${var.default_resource_group_name}"
  profile_name        = "${azurerm_traffic_manager_profile.netcoreapp.name}"
  target_resource_id  = "${azurerm_public_ip.myterraformpublicip[count.index].id}"
  type                = "azureEndpoints"
}

resource "azurerm_monitor_metric_alertrule" "trafficmanagermailrule" {
  name                = "${azurerm_traffic_manager_profile.netcoreapp.name}-primaryendpoint"
  resource_group_name = "${var.default_resource_group_name}"
  location            = "${var.default_region}"
  description         = "An alert rule to send a mail when the primary endpoint is down"
  enabled             = true

  resource_id = "${azurerm_traffic_manager_endpoint.endpoints[0].id}"
  metric_name = "Endpoint status by endpoint"
  operator    = "LessThan"
  threshold   = 1
  aggregation = "Average"
  period      = "PT5M"

  email_action {
    send_to_service_owners = false

    custom_emails = [
      "wrtv23@gmail.com"
    ]
  }
}
