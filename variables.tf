variable "domain_name_label" {
  description = "Base DNS label for the public IP addresses"
  default     = "ansibleterraform"
}

variable "vm_user" {
  description = "OS user to be created"
  default     = "azureuser"
}

variable "ssh_key" {
  description = "SSH key to be copied to the machines"
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDTVSc3KQYeaW3tnYnFrLMYILMhWXaA0ZBtbtEVM3lTSBfjJ5jhUxuYxASwI2uq9d2gl7WS4zvGKlpijSYj/g1iiNkBseQ+DwqxkN3R2mwNjgASvKEegFgWrHEhnBRYPas8wFrEXcAC2q9Je4AgzD1dybYSEHyfVFJJuLKfUtU8rVd5WhDGx7F0o1hNgGBFpuc9cM5/+WOISZRrgze6rwxvgbGLVw0q6U+vOqT46gE+A1CXpcP1TqcO4EwadQYunzLRs08HNLhLlSbG0hMYrPI+Uu8OdriT7HxjWIRf9FowJBFAxS4uR5TCGMBiSNb/LWxIJLWORu8eIav9rFAaMhDP adrian@adrian-K52Jr"
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
