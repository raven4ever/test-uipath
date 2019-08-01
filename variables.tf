variable "ansible_inventory_name" {
  description = "Tag to be used on VMs to be identified by Ansible"
  default     = "netcoreapp"
}

variable "vm_user" {
  description = "OS user to be created"
  default     = "azureuser"
}

variable "domain_name_label" {
  description = "Base DNS label for the public IP addresses"
  default     = "ansibleterraform"
}

variable "ssh_public_key" {
  description = "Path to SSH public key"
  default     = "/home/adrian/.ssh/id_rsa.pub"
}

variable "ssh_private_key" {
  description = "Path to SSH private key"
  default     = "/home/adrian/.ssh/id_rsa"
}

variable "default_region" {
  description = "default Azure region where resources are created"
  default     = "westeurope"
}

variable "default_resource_group_name" {
  description = "resource group name"
  default     = "homework-adrianpetcu-rg"
}

variable "vm_configuration" {
  type        = "list"
  description = "list of vms to be created"

  default = [
    {
      name                  = "primary"
      location              = "westeurope"
      vm_size               = "Standard_D2s_v3"
      vnet_name             = "primary_virtualnetwork"
      vnet_address_space    = "10.0.0.0/16"
      subnet_address_prefix = "10.0.1.0/24"

    },
    {
      name                  = "secondary"
      location              = "northeurope"
      vm_size               = "Standard_D2s_v3"
      vnet_name             = "secondary_virtualnetwork"
      vnet_address_space    = "10.1.0.0/16"
      subnet_address_prefix = "10.1.1.0/24"
    }
  ]
}
