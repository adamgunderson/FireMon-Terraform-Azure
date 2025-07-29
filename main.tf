# FireMon Security Intelligence Platform - Azure Deployment
# This Terraform configuration deploys FireMon SIP from Azure Marketplace

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.0"
}

# Configure the Azure Provider
provider "azurerm" {
  features {}
}

# Variables for customization
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-firemon-sip"
}

variable "location" {
  description = "Azure region for deployment"
  type        = string
  default     = "East US"
}

variable "vm_name" {
  description = "Name of the FireMon VM"
  type        = string
  default     = "vm-firemon-sip"
}

variable "vm_size" {
  description = "Size of the Azure VM"
  type        = string
  default     = "Standard_E16s_v3"  # 16 vCPUs, 128 GB RAM - suitable for up to 50 devices
}

variable "os_disk_size_gb" {
  description = "Size of the OS disk in GB"
  type        = number
  default     = 1000  # Default for AS/DB configuration; adjust based on deployment type
}

variable "admin_username" {
  description = "Administrator username for the VM"
  type        = string
  default     = "firemonadmin"
}

variable "admin_password" {
  description = "Administrator password for the VM"
  type        = string
  sensitive   = true
}

variable "allowed_source_ips" {
  description = "List of source IP addresses allowed to access FireMon"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Update with your specific IP ranges
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_address_prefix" {
  description = "Address prefix for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}

# Resource Group
resource "azurerm_resource_group" "firemon" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = "Production"
    Application = "FireMon Security Intelligence Platform"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "firemon" {
  name                = "vnet-firemon"
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.firemon.location
  resource_group_name = azurerm_resource_group.firemon.name

  tags = {
    Environment = "Production"
    Application = "FireMon SIP"
  }
}

# Subnet
resource "azurerm_subnet" "firemon" {
  name                 = "subnet-firemon"
  resource_group_name  = azurerm_resource_group.firemon.name
  virtual_network_name = azurerm_virtual_network.firemon.name
  address_prefixes     = [var.subnet_address_prefix]
}

# Network Security Group
resource "azurerm_network_security_group" "firemon" {
  name                = "nsg-firemon"
  location            = azurerm_resource_group.firemon.location
  resource_group_name = azurerm_resource_group.firemon.name

  # SSH Access
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.allowed_source_ips
    destination_address_prefix = "*"
  }

  # HTTPS Access for FireMon Web UI
  security_rule {
    name                       = "HTTPS"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = var.allowed_source_ips
    destination_address_prefix = "*"
  }

  # HTTP Access (redirect to HTTPS)
  security_rule {
    name                       = "HTTP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefixes    = var.allowed_source_ips
    destination_address_prefix = "*"
  }

  # FireMon Server Control Panel
  security_rule {
    name                       = "FireMon-Control-Panel"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "55555"
    source_address_prefixes    = var.allowed_source_ips
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "Production"
    Application = "FireMon SIP"
  }
}

# Public IP
resource "azurerm_public_ip" "firemon" {
  name                = "pip-firemon"
  location            = azurerm_resource_group.firemon.location
  resource_group_name = azurerm_resource_group.firemon.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = "Production"
    Application = "FireMon SIP"
  }
}

# Network Interface
resource "azurerm_network_interface" "firemon" {
  name                = "nic-firemon"
  location            = azurerm_resource_group.firemon.location
  resource_group_name = azurerm_resource_group.firemon.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.firemon.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.firemon.id
  }

  tags = {
    Environment = "Production"
    Application = "FireMon SIP"
  }
}

# Associate Network Security Group with Network Interface
resource "azurerm_network_interface_security_group_association" "firemon" {
  network_interface_id      = azurerm_network_interface.firemon.id
  network_security_group_id = azurerm_network_security_group.firemon.id
}

# Data source for FireMon marketplace image
data "azurerm_marketplace_agreement" "firemon" {
  publisher = "firemon"
  offer     = "firemon_sip_azure"
  plan      = "firemon_sip_azure"
}

# Accept marketplace terms (required for first deployment)
resource "azurerm_marketplace_agreement" "firemon" {
  publisher = data.azurerm_marketplace_agreement.firemon.publisher
  offer     = data.azurerm_marketplace_agreement.firemon.offer
  plan      = data.azurerm_marketplace_agreement.firemon.plan
}

# FireMon Virtual Machine
resource "azurerm_linux_virtual_machine" "firemon" {
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.firemon.name
  location            = azurerm_resource_group.firemon.location
  size                = var.vm_size

  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.firemon.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "firemon"
    offer     = "firemon_sip_azure"
    sku       = "firemon_sip_azure"
    version   = "latest"
  }

  plan {
    name      = "firemon_sip_azure"
    publisher = "firemon"
    product   = "firemon_sip_azure"
  }

  # Enable boot diagnostics
  boot_diagnostics {
    storage_account_uri = null  # Uses managed storage account
  }

  tags = {
    Environment = "Production"
    Application = "FireMon SIP"
  }

  depends_on = [azurerm_marketplace_agreement.firemon]
}

# Optional: Additional data disk if needed
resource "azurerm_managed_disk" "firemon_data" {
  count                = 0  # Set to 1 if you need an additional data disk
  name                 = "${var.vm_name}-data-disk"
  location             = azurerm_resource_group.firemon.location
  resource_group_name  = azurerm_resource_group.firemon.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 250

  tags = {
    Environment = "Production"
    Application = "FireMon SIP"
  }
}

# Attach data disk to VM (if created)
resource "azurerm_virtual_machine_data_disk_attachment" "firemon_data" {
  count              = length(azurerm_managed_disk.firemon_data)
  managed_disk_id    = azurerm_managed_disk.firemon_data[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.firemon.id
  lun                = 0
  caching            = "ReadWrite"
}

# Outputs
output "firemon_public_ip" {
  description = "Public IP address of FireMon SIP"
  value       = azurerm_public_ip.firemon.ip_address
}

output "firemon_setup_url" {
  description = "URL to access FireMon Initial Setup"
  value       = "https://${azurerm_public_ip.firemon.ip_address}:55555/setup"
}

output "firemon_web_url" {
  description = "URL to access FireMon Web UI (after setup)"
  value       = "https://${azurerm_public_ip.firemon.ip_address}"
}

output "firemon_control_panel_url" {
  description = "URL to access FireMon Server Control Panel"
  value       = "https://${azurerm_public_ip.firemon.ip_address}:55555"
}

output "ssh_connection_command" {
  description = "SSH connection command"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.firemon.ip_address}"
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.firemon.name
}

output "vm_name" {
  description = "Name of the FireMon VM"
  value       = azurerm_linux_virtual_machine.firemon.name
}