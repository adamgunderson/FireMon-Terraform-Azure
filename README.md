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
allowed_source_ips = ["YOUR_IP_ADDRESS/32"]  # Replace with your IP for security
location = "East US"  # Change to your preferred region
vm_size = "Standard_E16s_v3"  # Adjust based on your needs
os_disk_size_gb = 1000  # Adjust based on deployment type
```

3. Initialize and deploy:

```bash
terraform init
terraform plan
terraform apply
```

4. After deployment completes, access the setup URL shown in the outputs to complete initial configuration.

## Configuration Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `resource_group_name` | Name of the resource group | `rg-firemon-sip` | No |
| `location` | Azure region for deployment | `East US` | No |
| `vm_name` | Name of the FireMon VM | `vm-firemon-sip` | No |
| `vm_size` | Azure VM size | `Standard_E16s_v3` | No |
| `os_disk_size_gb` | OS disk size in GB | `1000` | No |
| `admin_username` | VM administrator username | `firemonadmin` | No |
| `admin_password` | VM administrator password | - | Yes |
| `allowed_source_ips` | IP addresses allowed to access FireMon | `["0.0.0.0/0"]` | No |
| `vnet_address_space` | Virtual network address space | `["10.0.0.0/16"]` | No |
| `subnet_address_prefix` | Subnet address prefix | `10.0.1.0/24` | No |

## Storage Requirements

Adjust the `disk_size_gb` in the Terraform configuration based on your deployment type:

- **All-in-One (AS/DB/DC)**: 1500 GB minimum
- **Standard AS/DB**: 1000 GB minimum
- **Data Collector only**: 500 GB minimum
- **Database server (distributed)**: 1500-2400 GB depending on device count

## Security Considerations

1. **Network Access**: 
   - Update `allowed_source_ips` to restrict access to your specific IP ranges
   - Consider using Azure Bastion for SSH access instead of public IP
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

1. **Access the Setup UI**:
   ```
   https://<public_ip_address>:55555/setup
   ```
   Replace `<public_ip_address>` with the IP shown in Terraform outputs.

2. **Authenticate to Setup**:
   - Username: The admin username specified in Terraform (default: `firemonadmin`)
   - Password: The admin password specified in Terraform
   - Click Submit

3. **Complete FMOS Initial Setup**:
   - After authentication, the FMOS Initial Setup form will appear
   - Follow the setup wizard to configure your system
   - You'll be prompted to change the initial password
   - Apply your FireMon license

4. **Access FireMon Web UI**:
   ```
   https://<public_ip_address>
   ```
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
