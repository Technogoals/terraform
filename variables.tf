variable "subscription_id" {
  description = "Azure subscription ID in which Terraform creates the resources."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be a valid Azure subscription UUID."
  }
}

variable "location" {
  description = "Policy-approved Azure region in which to create the VM and network resources."
  type        = string
  default     = "swedencentral"

  validation {
    condition = contains([
      "italynorth",
      "polandcentral",
      "spaincentral",
      "swedencentral",
      "switzerlandnorth"
    ], var.location)
    error_message = "location must be allowed by this subscription's regional policy."
  }
}

variable "resource_group_name" {
  description = "Name of the pre-created resource group for the VM resources."
  type        = string
  default     = "rg-terraform-vm"
}

variable "vm_name" {
  description = "Name of the virtual machine."
  type        = string
  default     = "vm-terraform-linux"
}

variable "vm_size" {
  description = "Azure VM SKU."
  type        = string
  default     = "Standard_D2als_v6"
}

variable "admin_username" {
  description = "Administrator username for SSH access."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to the local SSH public key."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "allowed_ssh_cidr" {
  description = "Source CIDR allowed to connect over SSH. Set this to your public IP as x.x.x.x/32."
  type        = string
  default     = "0.0.0.0/0"


  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "allowed_ssh_cidr must be a valid IPv4 or IPv6 CIDR block."
  }
}

variable "tags" {
  description = "Tags applied to all supported resources."
  type        = map(string)
  default = {
    environment = "dev"
    managed_by  = "terraform"
  }
}
