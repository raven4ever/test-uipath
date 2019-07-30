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
  name                  = "myVM"
  location              = "westeurope"
  resource_group_name   = "${var.default_resource_group_name}"
  network_interface_ids = ["${azurerm_network_interface.myterraformnic[0].id}"]
  vm_size               = "Standard_D2s_v3"

  storage_os_disk {
    name              = "myOsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "myvm"
    admin_username = "azureuser"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDTVSc3KQYeaW3tnYnFrLMYILMhWXaA0ZBtbtEVM3lTSBfjJ5jhUxuYxASwI2uq9d2gl7WS4zvGKlpijSYj/g1iiNkBseQ+DwqxkN3R2mwNjgASvKEegFgWrHEhnBRYPas8wFrEXcAC2q9Je4AgzD1dybYSEHyfVFJJuLKfUtU8rVd5WhDGx7F0o1hNgGBFpuc9cM5/+WOISZRrgze6rwxvgbGLVw0q6U+vOqT46gE+A1CXpcP1TqcO4EwadQYunzLRs08HNLhLlSbG0hMYrPI+Uu8OdriT7HxjWIRf9FowJBFAxS4uR5TCGMBiSNb/LWxIJLWORu8eIav9rFAaMhDP adrian@adrian-K52Jr"
    }
  }
}

