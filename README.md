# FireMon Security Intelligence Platform - Azure Terraform Deployment

This Terraform configuration deploys FireMon Security Intelligence Platform from the Azure Marketplace with all necessary infrastructure components.

## Prerequisites

1. **Azure Subscription**: Active Azure subscription with appropriate permissions
2. **Terraform**: Version 1.0 or higher installed
3. **Azure CLI**: Installed and authenticated (`az login`)
4. **FireMon License**: You'll need a valid FireMon license after deployment

## Quick Start

1. Clone or download the Terraform configuration files
2. Create a `terraform.tfvars` file with your specific values:

```hcl
admin_password = "YourSecurePassword123!"
deploy_public_ip = false  # Set to true only if external access needed
allowed_source_ips = ["YOUR_IP_ADDRESS/32"]  # Only relevant if public IP enabled
location = "East US"  # Change to your preferred region
vm_size = "Standard_E16s_v3"  # Adjust based on your needs
data_disk_size_gb = 1200  # Adjust based on your storage requirements
```

3. Initialize and deploy:

```bash
terraform init
terraform plan
terraform apply
```

4. After deployment completes, you'll see outputs including:
   - Public IP address (if enabled)
   - Private IP address
   - Setup URLs
   - Data disk information (size as configured)
   - SSH connection command

5. Follow the post-deployment steps to configure the data disk and complete initial setup.

## Configuration Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `resource_group_name` | Name of the resource group | `rg-firemon-sip` | No |
| `location` | Azure region for deployment | `East US` | No |
| `vm_name` | Name of the FireMon VM | `vm-firemon-sip` | No |
| `vm_size` | Azure VM size | `Standard_E16s_v3` | No |
| `data_disk_size_gb` | Size of data disk in GB | `1200` | No |
| `admin_username` | VM administrator username | `firemonadmin` | No |
| `admin_password` | VM administrator password | - | Yes |
| `deploy_public_ip` | Deploy a public IP for external access | `false` | No |
| `allowed_source_ips` | IP addresses allowed to access FireMon | `["0.0.0.0/0"]` | No |
| `vnet_address_space` | Virtual network address space | `["10.0.0.0/16"]` | No |
| `subnet_address_prefix` | Subnet address prefix | `10.0.1.0/24` | No |

## Azure Marketplace Image

This Terraform configuration automatically deploys the FireMon Security Intelligence Platform from Azure Marketplace. Here's how it works:

### Image Source
- **Marketplace URL**: [FireMon SIP on Azure Marketplace](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/firemon.firemon_sip_azure)
- **Publisher**: `firemon`
- **Offer**: `firemon_sip_azure`
- **Plan/SKU**: `firemon_sip_azure`

### How Terraform Loads the Image

1. **Marketplace Agreement**: The configuration automatically accepts the marketplace terms on first deployment
2. **Image Reference**: The VM uses `source_image_reference` to specify the exact marketplace image
3. **Plan Information**: The `plan` block confirms the commercial terms and licensing
4. **Version**: Set to `latest` to always deploy the most recent stable version

The FireMon virtual appliance image includes:
- Pre-configured FireMon Operating System (FMOS)
- All necessary FireMon applications and services
- Automatic detection and configuration of attached data disks
- Built-in security hardening

## Storage Configuration

This deployment includes two disks:

### OS Disk
- **Type**: Premium SSD (LRS)
- **Size**: Uses the default size from the FireMon Azure Marketplace image
- **Purpose**: Operating system and FireMon application

### Data Disk
- **Type**: Premium SSD (LRS)
- **Size**: Configurable via `data_disk_size_gb` variable (default: 1200 GB)
- **Purpose**: Data storage, logs, backups, and database files
- **LUN**: 0
- **Caching**: ReadWrite
- **Auto-Detection**: FireMon automatically detects and configures this disk on first boot

### Recommended Data Disk Sizes

| Environment Size | Devices | Recommended Size | Variable Setting |
|-----------------|---------|------------------|------------------|
| Small | ≤25 | 500 GB | `data_disk_size_gb = 500` |
| Standard | ≤50 | 1200 GB | `data_disk_size_gb = 1200` (default) |
| Medium | 51-150 | 1500 GB | `data_disk_size_gb = 1500` |
| Large | 151-500 | 2000 GB | `data_disk_size_gb = 2000` |
| Very Large | 500+ | 2400 GB | `data_disk_size_gb = 2400` |

## VM Size and Storage Recommendations

| Environment | Devices | VM Size | Data Disk Size |
|-------------|---------|---------|----------------|
| Small/Test | ≤25 | `Standard_E8s_v3` (8 vCPUs, 64 GB RAM) | 500 GB |
| Standard | ≤50 | `Standard_E16s_v3` (16 vCPUs, 128 GB RAM) | 1200 GB |
| Medium | 51-150 | `Standard_E32s_v3` (32 vCPUs, 256 GB RAM) | 1500 GB |
| Large | 151-500 | `Standard_E32s_v3` (32 vCPUs, 256 GB RAM) | 2000 GB |
| Very Large | 500+ | `Standard_E48s_v3` (48 vCPUs, 384 GB RAM) or larger | 2400 GB |

## Security Considerations

1. **Network Access**: 
   - **Default Configuration**: No public IP (enterprise-secure by default)
   - Only set `deploy_public_ip = true` if absolutely necessary for external access
   - Update `allowed_source_ips` to restrict access to your specific IP ranges (only relevant with public IP)
   - **Recommended**: Use Azure Bastion, VPN, or ExpressRoute for secure access
   - Implement Azure Firewall or Network Virtual Appliance for additional security

2. **Authentication**:
   - Use strong passwords or SSH keys
   - Consider implementing Azure AD authentication
   - Enable Multi-Factor Authentication (MFA) within FireMon

3. **Disk Encryption**:
   - Enable Azure Disk Encryption for OS and data disks
   - Use Azure Key Vault for key management

## Post-Deployment Steps

### Initial Setup and Authentication

When FMOS boots for the first time in Azure, it automatically creates an initial administrative user account using the credentials specified during VM creation.

**Important Note**: 
- If you use SSH keys instead of a password during VM creation, the initial FMOS password will be the first 12 characters of the base64-encoded SHA256 fingerprint of your SSH public key.
- The current Terraform configuration uses password authentication. If you need SSH key authentication, you'll need to modify the `azurerm_linux_virtual_machine` resource.

**Step 1: Access the Setup UI**:
   - **With Public IP**: `https://<public_ip_address>:55555/setup`
   - **Internal Only**: `https://<private_ip_address>:55555/setup` (access via Bastion, VPN, or from within the VNet)
   
   Replace with the appropriate IP address shown in Terraform outputs.

**Step 2: Authenticate to Setup**:
   - Username: The admin username specified in Terraform (default: `firemonadmin`)
   - Password: The admin password specified in Terraform
   - Click Submit

**Step 3: Complete FMOS Initial Setup**:
   - After authentication, the FMOS Initial Setup form will appear
   - Follow the setup wizard to configure your system
   - You'll be prompted to change the initial password
   - Apply your FireMon license

**Step 4: Access FireMon Web UI**:
   - **With Public IP**: `https://<public_ip_address>`
   - **Internal Only**: `https://<private_ip_address>` (via Bastion, VPN, or internal network)
   
   Use your new credentials to log into the main FireMon interface.

## Network Ports

The following ports are configured in the Network Security Group:

| Port | Protocol | Purpose |
|------|----------|---------|
| 22 | TCP | SSH access |
| 80 | TCP | HTTP (redirects to HTTPS) |
| 443 | TCP | HTTPS Web UI |
| 55555 | TCP | FireMon Server Control Panel |

## Troubleshooting

### Common Issues

1. **Marketplace Terms Not Accepted**:
   ```bash
   az vm image accept-terms --publisher firemon --offer firemon_sip_azure --plan firemon_sip_azure
   ```

2. **Cannot Access Web UI**:
   - Verify NSG rules allow your source IP
   - Check VM is running: `az vm show -g <resource_group> -n <vm_name>`
   - Review boot diagnostics in Azure Portal

3. **Performance Issues**:
   - Upgrade VM size if needed
   - Enable accelerated networking
   - Review FireMon logs at `/var/log/firemon/`

### Support Resources

- FireMon Documentation: https://docs.firemon.com
- FireMon Support Portal: https://support.firemon.com
- Azure Support: https://azure.microsoft.com/support

## Cleanup

To remove all resources:
```bash
terraform destroy
```

## License

This Terraform configuration is provided as-is. FireMon Security Intelligence Platform requires a valid license from FireMon.