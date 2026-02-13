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

# OS disk size is now using the default from the marketplace image
# variable "os_disk_size_gb" removed - using marketplace default

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

variable "deploy_public_ip" {
  description = "Deploy a public IP for the VM (set to false for internal-only access)"
  type        = bool
  default     = false  # Default to no public IP for enterprise security
}

variable "data_disk_size_gb" {
  description = "Size of the additional data disk in GB for logs, backups, and data storage"
  type        = number
  default     = 1200  # 1200GB provides ample space for most deployments
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

# Public IP (Optional - only created if deploy_public_ip = true)
resource "azurerm_public_ip" "firemon" {
  count               = var.deploy_public_ip ? 1 : 0
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
    public_ip_address_id          = var.deploy_public_ip ? azurerm_public_ip.firemon[0].id : null
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

# ================================================================================
# AZURE MARKETPLACE IMAGE CONFIGURATION
# This section configures how the FireMon image is loaded from Azure Marketplace
# Marketplace URL: https://azuremarketplace.microsoft.com/en-us/marketplace/apps/firemon.firemon_sip_azure
# ================================================================================

# Data source to retrieve the FireMon marketplace image details
# This fetches the current marketplace agreement for the FireMon SIP image
data "azurerm_marketplace_agreement" "firemon" {
  publisher = "firemon"           # Publisher ID in Azure Marketplace
  offer     = "firemon_sip_azure" # The offer ID for FireMon SIP
  plan      = "firemon_sip_azure" # The specific plan/SKU to use
}

# Accept marketplace terms (required for first deployment)
# This is mandatory - Azure requires accepting terms before using marketplace images
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
    # Using default size from FireMon marketplace image
  }

  # SOURCE IMAGE REFERENCE - This tells Azure which marketplace image to use
  # This references the FireMon virtual appliance image from Azure Marketplace
  source_image_reference {
    publisher = "firemon"           # Must match the marketplace publisher
    offer     = "firemon_sip_azure" # Must match the marketplace offer
    sku       = "firemon_sip_azure" # Must match the marketplace SKU
    version   = "latest"            # Uses the latest version available
  }

  # PLAN - Required for marketplace images with commercial terms
  # This confirms which specific marketplace plan/product to use
  plan {
    name      = "firemon_sip_azure" # Plan name from marketplace
    publisher = "firemon"           # Publisher ID
    product   = "firemon_sip_azure" # Product ID from marketplace
  }

  # Cloud-init bootcmd to wait for the data disk before FMOS initialization.
  # azurerm_linux_virtual_machine does not support inline data disk blocks, so the
  # disk is attached via azurerm_virtual_machine_data_disk_attachment after VM
  # creation. This bootcmd pauses early boot until the LUN 0 device appears,
  # ensuring FireMon's first-boot auto-detection sees the data disk.
  # Ref: https://github.com/hashicorp/terraform-provider-azurerm/issues/6117
  custom_data = base64encode(join("\n", [
    "#cloud-config",
    "bootcmd:",
    "  - |",
    "    count=0",
    "    while [ ! -e /dev/disk/azure/scsi1/lun0 ]; do",
    "      sleep 5",
    "      count=$((count + 1))",
    "      if [ $count -ge 60 ]; then",
    "        echo 'Timeout waiting for data disk at LUN 0 after 300s' | logger -t cloud-init-disk-wait",
    "        break",
    "      fi",
    "    done",
    "    echo 'Data disk detected at LUN 0' | logger -t cloud-init-disk-wait",
  ]))

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

# Additional Premium SSD data disk for logs, backups, and data storage
resource "azurerm_managed_disk" "firemon_data" {
  count                = 1  # Enabled - creates one data disk
  name                 = "${var.vm_name}-data-disk"
  location             = azurerm_resource_group.firemon.location
  resource_group_name  = azurerm_resource_group.firemon.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb  # Configurable disk size

  tags = {
    Environment = "Production"
    Application = "FireMon SIP"
    DiskType    = "Data"
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
output "firemon_private_ip" {
  description = "Private IP address of FireMon SIP"
  value       = azurerm_network_interface.firemon.private_ip_address
}

output "firemon_public_ip" {
  description = "Public IP address of FireMon SIP (if deployed)"
  value       = var.deploy_public_ip ? azurerm_public_ip.firemon[0].ip_address : "No public IP deployed"
}

output "firemon_setup_url" {
  description = "URL to access FireMon Initial Setup"
  value       = var.deploy_public_ip ? "https://${azurerm_public_ip.firemon[0].ip_address}:55555/setup" : "https://${azurerm_network_interface.firemon.private_ip_address}:55555/setup (internal access only)"
}

output "firemon_web_url" {
  description = "URL to access FireMon Web UI (after setup)"
  value       = var.deploy_public_ip ? "https://${azurerm_public_ip.firemon[0].ip_address}" : "https://${azurerm_network_interface.firemon.private_ip_address} (internal access only)"
}

output "firemon_control_panel_url" {
  description = "URL to access FireMon Server Control Panel"
  value       = var.deploy_public_ip ? "https://${azurerm_public_ip.firemon[0].ip_address}:55555" : "https://${azurerm_network_interface.firemon.private_ip_address}:55555 (internal access only)"
}

output "ssh_connection_command" {
  description = "SSH connection command"
  value       = var.deploy_public_ip ? "ssh ${var.admin_username}@${azurerm_public_ip.firemon[0].ip_address}" : "ssh ${var.admin_username}@${azurerm_network_interface.firemon.private_ip_address} (use bastion or VPN for access)"
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.firemon.name
}

output "vm_name" {
  description = "Name of the FireMon VM"
  value       = azurerm_linux_virtual_machine.firemon.name
}

output "data_disk_info" {
  description = "Information about the attached data disk"
  value = length(azurerm_managed_disk.firemon_data) > 0 ? {
    name     = azurerm_managed_disk.firemon_data[0].name
    size_gb  = azurerm_managed_disk.firemon_data[0].disk_size_gb
    type     = azurerm_managed_disk.firemon_data[0].storage_account_type
    lun      = 0
  } : "No data disk attached"
}
