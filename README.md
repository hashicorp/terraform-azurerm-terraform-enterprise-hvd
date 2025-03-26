# Terraform Enterprise HVD on Azure VM

Terraform module aligned with HashiCorp Validated Designs (HVD) to deploy Terraform Enterprise (TFE) on Microsoft Azure using Azure Virtual Machines with a container runtime. This module defaults to deploying TFE in the `active-active` [operational mode](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/operation-modes), but `external` is also supported. Docker and Podman are the supported container runtimes.

![TFE architecture](https://developer.hashicorp.com/.extracted/hvd/img/terraform/solution-design-guides/tfe/architecture-logical-active-active.png)

## Prerequisites

### General

- TFE license file (_e.g._ `terraform.hclic`).
- Terraform CLI `>= 1.9` installed on clients/workstations that will be used to deploy TFE
- General understanding of how to use Terraform (Community Edition)
- General understanding of how to use Azure cloud
- `git` CLI and Visual Studio Code editor installed on workstations are strongly recommended
- Azure subscription that TFE will be deployed in with admin-like permissions to provision these [resources](#resources) in via Terraform CLI
- Azure blob storage account for [AzureRM remote state backend](https://www.terraform.io/docs/language/settings/backends/azurerm.html) that will be used to manage the Terraform state of this TFE deployment (out-of-band from the TFE application) via Terraform CLI (Community Edition)

### Networking

- Azure VNet ID.
- Load balancer subnet ID (if load balancer is to be _internal_)
- Load balancer static IP address (if load balancer is to be _internal_)
- VM subnet ID with service endpoints enabled for `Microsoft.KeyVault`, `Microsoft.Sql`, and `Microsoft.Storage`
- VM subnet requires access to the egress endpoints listed [here](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/requirements/network#egress)
- Database subnet ID with service delegation configured for `Microsoft.DBforPostgreSQL/flexibleServers` for join action (`Microsoft.Network/virtualNetworks/subnets/join/action`)
- Redis cache subnet ID
- Ability to create private endpoints on the database and redis cache subnets
- Chosen fully qualified domain name (FQDN) for your TFE instance (_e.g._ `tfe.azure.example.com`)

#### Network security group (NSG)/firewall rules

- Allow `TCP/443` ingress to load balancer subnet (if TFE load balancer is to be _internal_) or VM subnet (if TFE load balancer is to be _external_) from CIDR ranges of TFE users/clients, your VCS, and other systems (such as CI/CD) that will need to access TFE
- (Optional) Allow `TCP/9091` (HTTPS) and/or `TCP/9090` (HTTP) ingress to VM subnet from monitoring/observability tool CIDR range (for scraping TFE metrics endpoints)
- Allow `TCP/5432` ingress to database subnet from VM subnet (for PostgreSQL traffic)
- Allow `TCP/6380` ingress to Redis cache subnetfrom VM subnet (for Redis TLS traffic)
- Allow `TCP/8201` between VMs on VM subnet (for TFE embedded Vault internal cluster traffic between TFE nodes when `tfe_operational_mode` is `active-active`)

### TLS certificates

- TLS certificate (_e.g._ `cert.pem`) and private key (_e.g._ `privkey.pem`) that matches your chosen fully qualified domain name (FQDN) for TFE
  - TLS certificate and private key must be in PEM format
  - Private key must **not** be password protected
- TLS certificate authority (CA) bundle (_e.g._ `ca_bundle.pem`) corresponding with the CA that issues your TFE TLS certificates
  - CA bundle must be in PEM format
  - You may include additional certificate chains corresponding to external systems that TFE will make outbound connections to (_e.g._ your self-hosted VCS, if its certificate was issued by a different CA than your TFE certificate)

### Key Vault secrets

Azure Key Vault containing the following TFE _bootstrap_ secrets:

- **TFE license** - raw contents of TFE license file (i.e. the string value of `cat terraform.hclic`)
- **TFE encryption password** - used for TFE's embedded Vault; randomly generate this yourself, this is kept completely internal to the TFE system
- **TFE database password** - used to create PostgreSQL Flexible Server; randomly generate this yourself (avoid the `$` character as Azure PostgreSQL Flexible Server does not like it), fetched from within the module via data source and applied to the PostgreSQL Flexible Server resource
- **TFE TLS certificate** - base64-encoded string of certificate file in PEM format
- **TFE TLS private key** - base64-encoded string of private key file in PEM format
- **TFE custom CA bundle** - base64-encoded string of custom CA bundle file in PEM format

 >📝 Note: See the [TFE TLS Certificate Rotation](./docs/tfe-cert-rotation.md) doc for instructions on how to base64-encode the certificates with proper formatting before storing them as Key Vault secrets.

### Compute

- Supported operating systems:
  - RHEL 8.x, 9.x
  - Ubuntu 22.x, 24.x

- One of the following mechanisms for shell access to TFE Azure Linux VMs within the Virtual Machine Scale Set (VMSS):
  - SSH key pair (public key would be a module input)
  - Username/password (password would be a module input)

- Bastion host (if VM subnet is not reachable from clients/workstations)

### Log forwarding (optional)

One of the following logging destinations for the TFE container logs:

- Azure Log Analytics Workspace
- A custom Fluent Bit configuration to forward logs to a custom destination

## Usage

1. Create/configure/validate the applicable [prerequisites](#prerequisites).

1. Within the [examples/main](./examples/main) directory is a ready-made Terraform configuration which contains example scenarios on how to call and deploy this module. To get started, choose the example scenario that most closely matches your requirements. You can customize your deployment later by adding additional module [inputs](#inputs) as you see fit (see the [Deployment-Customizations](./docs/deployment-customizations.md) for more details).

1. Copy all of the Terraform files from your example scenario of choice into a new destination directory to create your Terraform configuration that will manage your TFE deployment. This is a common directory structure for managing multiple TFE deployments:

    ```pre
    .
    └── environments
        ├── production
        │   ├── backend.tf
        │   ├── main.tf
        │   ├── outputs.tf
        │   ├── terraform.tfvars
        │   └── variables.tf
        └── sandbox
            ├── backend.tf
            ├── main.tf
            ├── outputs.tf
            ├── terraform.tfvars
            └── variables.tf
    ```

    >📝 Note: In this example, the user will have two separate TFE deployments; one for their `sandbox` environment, and one for their `production` environment. This is recommended, but not required.

1. (Optional) Uncomment and update the [AzureRM Remote State backend](https://www.terraform.io/docs/language/settings/backends/azurerm.html) configuration provided in the `backend.tf` file with your own custom values. While this step is highly recommended so that your state file managing your TFE deployment is not stored on your local disk and others can safely collaborate, it is technically not required to use a remote backend config for your TFE deployment.

1. Populate your own custom values into the `terraform.tfvars.example` file that was provided (in particular, the values enclosed in the `<>` characters). Then, remove the `.example` file extension such that the file is now named `terraform.tfvars`. If you would like to further customize your deployment beyond what is in your chosen example scenario, see the [deployment customizations](./docs/deployment-customizations.md) doc for more details on common customizations.

1. Navigate to the directory of your newly created Terraform configuration for your TFE deployment, and run `terraform init`, `terraform plan`, and `terraform apply`.

1. After your `terraform apply` finishes successfully, you can monitor the installation progress by connecting to your TFE VM shell (via SSH or other preferred method) and observing the cloud-init (custom_data) script logs:<br>

   **Connecting to the Azure VM**

   ```shell
   ssh -i /path/to/vm_ssh_private_key tfeadmin@<vm-private-ip>
   ```

   **Viewing the logs**

   View the higher-level logs:

   ```shell
   tail -f /var/log/tfe-cloud-init.log
   ```

   View the lower-level logs:

   ```shell
   journalctl -xu cloud-final -f
   ```

   >📝 Note: the `-f` argument is to follow the logs as they append in real-time, and is optional. You may remove the `-f` for a static view.

   **Successful install log message**

   The log files should display the following message after the cloud-init (custom_data) script finishes successfully:

   ```shell
   [INFO] TFE custom_data script finished successfully!
   ```

1. After the cloud-init (custom_data) script finishes successfully, while still connected to the TFE VM shell, you can check the health status of TFE:

   ```shell
   cd /etc/tfe
   sudo docker compose exec tfe tfe-health-check-status
   ```

1. Follow the steps to [create the TFE initial admin user](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/initial-admin-user).

## Docs

Below are links to various docs related to the customization and management of your TFE deployment:

- [Deployment Customizations](./docs/deployment-customizations.md)
- [TFE Version Upgrades](./docs/tfe-version-upgrades.md)
- [TFE TLS Certificate Rotation](./docs/tfe-cert-rotation.md)
- [TFE Configuration Settings](./docs/tfe-config-settings.md)
- [Azure GovCloud Deployment](./docs/govcloud-deployment.md)

## Module support

This open source software is maintained by the HashiCorp Technical Field Organization, independently of our enterprise products. While our Support Engineering team provides dedicated support for our enterprise offerings, this open source software is not included.

- For help using this open source software, please engage your account team.
- To report bugs/issues with this open source software, please open them directly against this code repository using the GitHub issues feature.

Please note that there is no official Service Level Agreement (SLA) for support of this software as a HashiCorp customer. This software falls under the definition of Community Software/Versions in your Agreement. We appreciate your understanding and collaboration in improving our open source projects.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 3.117 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~> 3.117 |

## Resources

| Name | Type |
|------|------|
| [azurerm_dns_a_record.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/dns_a_record) | resource |
| [azurerm_key_vault_access_policy.postgres_cmk](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_access_policy) | resource |
| [azurerm_key_vault_access_policy.storage_account_cmk](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_access_policy) | resource |
| [azurerm_key_vault_access_policy.tfe_kv_reader](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_access_policy) | resource |
| [azurerm_lb.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb) | resource |
| [azurerm_lb_backend_address_pool.tfe_servers](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_backend_address_pool) | resource |
| [azurerm_lb_probe.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_probe) | resource |
| [azurerm_lb_rule.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_rule) | resource |
| [azurerm_linux_virtual_machine_scale_set.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine_scale_set) | resource |
| [azurerm_postgresql_flexible_server.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server) | resource |
| [azurerm_postgresql_flexible_server_configuration.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server_configuration) | resource |
| [azurerm_postgresql_flexible_server_database.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server_database) | resource |
| [azurerm_private_dns_a_record.blob_storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_a_record) | resource |
| [azurerm_private_dns_a_record.redis](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_a_record) | resource |
| [azurerm_private_dns_a_record.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_a_record) | resource |
| [azurerm_private_dns_zone.blob_storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) | resource |
| [azurerm_private_dns_zone.postgres](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) | resource |
| [azurerm_private_dns_zone.redis](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) | resource |
| [azurerm_private_dns_zone_virtual_network_link.blob_storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link) | resource |
| [azurerm_private_dns_zone_virtual_network_link.postgres](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link) | resource |
| [azurerm_private_dns_zone_virtual_network_link.redis](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link) | resource |
| [azurerm_private_endpoint.blob_storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_private_endpoint.redis](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_public_ip.tfe_lb](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_redis_cache.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/redis_cache) | resource |
| [azurerm_resource_group.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.tfe_kv_reader](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.tfe_sa_owner](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.tfe_vmss_disk_encryption_set_reader](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_storage_account.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_storage_account_network_rules.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account_network_rules) | resource |
| [azurerm_storage_container.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) | resource |
| [azurerm_user_assigned_identity.postgres](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [azurerm_user_assigned_identity.storage_account](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [azurerm_user_assigned_identity.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_disk_encryption_set.vmss](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/disk_encryption_set) | data source |
| [azurerm_dns_zone.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/dns_zone) | data source |
| [azurerm_image.custom](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/image) | data source |
| [azurerm_key_vault.bootstrap](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |
| [azurerm_key_vault_secret.tfe_database_password](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_log_analytics_workspace.logging](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/log_analytics_workspace) | data source |
| [azurerm_platform_image.latest_os_image](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/platform_image) | data source |
| [azurerm_private_dns_zone.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/private_dns_zone) | data source |
| [azurerm_storage_account.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/storage_account) | data source |
| [azurerm_storage_container.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/storage_container) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bootstrap_keyvault_name"></a> [bootstrap\_keyvault\_name](#input\_bootstrap\_keyvault\_name) | Name of the 'bootstrap' Key Vault to use for bootstrapping TFE deployment. | `string` | n/a | yes |
| <a name="input_bootstrap_keyvault_rg_name"></a> [bootstrap\_keyvault\_rg\_name](#input\_bootstrap\_keyvault\_rg\_name) | Name of the Resource Group where the 'bootstrap' Key Vault resides. | `string` | n/a | yes |
| <a name="input_container_runtime"></a> [container\_runtime](#input\_container\_runtime) | Value of container runtime to use for TFE deployment. For Redhat, the default is `podman`, but optionally `docker` can be used. For Ubuntu, the default is `docker`. | `string` | n/a | yes |
| <a name="input_db_subnet_id"></a> [db\_subnet\_id](#input\_db\_subnet\_id) | Subnet ID for PostgreSQL database. | `string` | n/a | yes |
| <a name="input_friendly_name_prefix"></a> [friendly\_name\_prefix](#input\_friendly\_name\_prefix) | Friendly name prefix used for uniquely naming all Azure resources for this deployment. Most commonly set to either an environment (e.g. 'sandbox', 'prod'), a team name, or a project name. | `string` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | Azure region for this TFE deployment. | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of resource group for this TFE deployment. Must be an existing resource group if `create_resource_group` is `false`. | `string` | n/a | yes |
| <a name="input_tfe_database_password_keyvault_secret_name"></a> [tfe\_database\_password\_keyvault\_secret\_name](#input\_tfe\_database\_password\_keyvault\_secret\_name) | Name of the secret in the Key Vault that contains the TFE database password. | `string` | n/a | yes |
| <a name="input_tfe_encryption_password_keyvault_secret_id"></a> [tfe\_encryption\_password\_keyvault\_secret\_id](#input\_tfe\_encryption\_password\_keyvault\_secret\_id) | ID of Key Vault secret containing TFE encryption password. | `string` | n/a | yes |
| <a name="input_tfe_fqdn"></a> [tfe\_fqdn](#input\_tfe\_fqdn) | Fully qualified domain name of TFE instance. This name should resolve to the load balancer IP address and will be what clients use to access TFE. | `string` | n/a | yes |
| <a name="input_tfe_license_keyvault_secret_id"></a> [tfe\_license\_keyvault\_secret\_id](#input\_tfe\_license\_keyvault\_secret\_id) | ID of Key Vault secret containing TFE license. | `string` | n/a | yes |
| <a name="input_tfe_tls_ca_bundle_keyvault_secret_id"></a> [tfe\_tls\_ca\_bundle\_keyvault\_secret\_id](#input\_tfe\_tls\_ca\_bundle\_keyvault\_secret\_id) | ID of Key Vault secret containing TFE TLS custom CA bundle. | `string` | n/a | yes |
| <a name="input_tfe_tls_cert_keyvault_secret_id"></a> [tfe\_tls\_cert\_keyvault\_secret\_id](#input\_tfe\_tls\_cert\_keyvault\_secret\_id) | ID of Key Vault secret containing TFE TLS certificate. | `string` | n/a | yes |
| <a name="input_tfe_tls_privkey_keyvault_secret_id"></a> [tfe\_tls\_privkey\_keyvault\_secret\_id](#input\_tfe\_tls\_privkey\_keyvault\_secret\_id) | ID of Key Vault secret containing TFE TLS private key. | `string` | n/a | yes |
| <a name="input_vm_subnet_id"></a> [vm\_subnet\_id](#input\_vm\_subnet\_id) | Subnet ID for Virtual Machine Scaleset (VMSS). | `string` | n/a | yes |
| <a name="input_vnet_id"></a> [vnet\_id](#input\_vnet\_id) | ID of VNet where TFE will be deployed. | `string` | n/a | yes |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | List of Azure availability zones to spread TFE resources across. | `set(string)` | <pre>[<br/>  "1",<br/>  "2",<br/>  "3"<br/>]</pre> | no |
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | Map of common tags for taggable Azure resources. | `map(string)` | `{}` | no |
| <a name="input_create_blob_storage_private_endpoint"></a> [create\_blob\_storage\_private\_endpoint](#input\_create\_blob\_storage\_private\_endpoint) | Boolean to create a private endpoint and private DNS zone for TFE Storage Account. | `bool` | `true` | no |
| <a name="input_create_lb"></a> [create\_lb](#input\_create\_lb) | Boolean to create an Azure Load Balancer for TFE. | `bool` | `true` | no |
| <a name="input_create_postgres_private_endpoint"></a> [create\_postgres\_private\_endpoint](#input\_create\_postgres\_private\_endpoint) | Boolean to create a private endpoint and private DNS zone for PostgreSQL Flexible Server. | `bool` | `true` | no |
| <a name="input_create_redis_private_endpoint"></a> [create\_redis\_private\_endpoint](#input\_create\_redis\_private\_endpoint) | Boolean to create a private DNS zone and private endpoint for Redis cache. | `bool` | `true` | no |
| <a name="input_create_resource_group"></a> [create\_resource\_group](#input\_create\_resource\_group) | Boolean to create a new resource group for this TFE deployment. | `bool` | `true` | no |
| <a name="input_create_tfe_private_dns_record"></a> [create\_tfe\_private\_dns\_record](#input\_create\_tfe\_private\_dns\_record) | Boolean to create a DNS record for TFE in a private Azure DNS zone. A `private_dns_zone_name` must also be provided when `true`. | `bool` | `false` | no |
| <a name="input_create_tfe_public_dns_record"></a> [create\_tfe\_public\_dns\_record](#input\_create\_tfe\_public\_dns\_record) | Boolean to create a DNS record for TFE in a public Azure DNS zone. A `public_dns_zone_name` must also be provided when `true`. | `bool` | `false` | no |
| <a name="input_custom_fluent_bit_config"></a> [custom\_fluent\_bit\_config](#input\_custom\_fluent\_bit\_config) | Custom Fluent Bit configuration for log forwarding. Only valid if `log_fwd_destination_type` is `custom`. | `string` | `null` | no |
| <a name="input_docker_version"></a> [docker\_version](#input\_docker\_version) | Version of Docker to install on TFE VMSS. | `string` | `"24.0.9"` | no |
| <a name="input_is_govcloud_region"></a> [is\_govcloud\_region](#input\_is\_govcloud\_region) | Boolean indicating whether this TFE deployment is in an Azure Government Cloud region. | `bool` | `false` | no |
| <a name="input_is_secondary_region"></a> [is\_secondary\_region](#input\_is\_secondary\_region) | Boolean indicating whether this TFE deployment is for 'primary' region or 'secondary' region. | `bool` | `false` | no |
| <a name="input_lb_is_internal"></a> [lb\_is\_internal](#input\_lb\_is\_internal) | Boolean to create an internal or external Azure Load Balancer for TFE. | `bool` | `true` | no |
| <a name="input_lb_private_ip"></a> [lb\_private\_ip](#input\_lb\_private\_ip) | Private IP address for internal Azure Load Balancer. Only valid when `lb_is_internal` is `true`. | `string` | `null` | no |
| <a name="input_lb_subnet_id"></a> [lb\_subnet\_id](#input\_lb\_subnet\_id) | Subnet ID for Azure load balancer. | `string` | `null` | no |
| <a name="input_log_analytics_workspace_name"></a> [log\_analytics\_workspace\_name](#input\_log\_analytics\_workspace\_name) | Name existing Azure Log Analytics Workspace for log forwarding destination. Only valid if `log_fwd_destination_type` is `log_analytics`. | `string` | `null` | no |
| <a name="input_log_analytics_workspace_rg_name"></a> [log\_analytics\_workspace\_rg\_name](#input\_log\_analytics\_workspace\_rg\_name) | Name of Resource Group where Log Analytics Workspace exists. | `string` | `null` | no |
| <a name="input_log_fwd_destination_type"></a> [log\_fwd\_destination\_type](#input\_log\_fwd\_destination\_type) | Type of log forwarding destination. Valid values are 'log\_analytics' or 'custom'. | `string` | `"log_analytics"` | no |
| <a name="input_postgres_administrator_login"></a> [postgres\_administrator\_login](#input\_postgres\_administrator\_login) | Username for administrator login of PostreSQL database. | `string` | `"tfeadmin"` | no |
| <a name="input_postgres_backup_retention_days"></a> [postgres\_backup\_retention\_days](#input\_postgres\_backup\_retention\_days) | Number of days to retain backups of PostgreSQL Flexible Server. | `number` | `35` | no |
| <a name="input_postgres_cmk_keyvault_id"></a> [postgres\_cmk\_keyvault\_id](#input\_postgres\_cmk\_keyvault\_id) | ID of the Key Vault containing the customer-managed key (CMK) for encrypting the PostgreSQL Flexible Server database. | `string` | `null` | no |
| <a name="input_postgres_cmk_keyvault_key_id"></a> [postgres\_cmk\_keyvault\_key\_id](#input\_postgres\_cmk\_keyvault\_key\_id) | ID of the Key Vault key to use for customer-managed key (CMK) encryption of PostgreSQL Flexible Server database. | `string` | `null` | no |
| <a name="input_postgres_create_mode"></a> [postgres\_create\_mode](#input\_postgres\_create\_mode) | Determines if the PostgreSQL Flexible Server is being created as a new server or as a replica. | `string` | `"Default"` | no |
| <a name="input_postgres_enable_high_availability"></a> [postgres\_enable\_high\_availability](#input\_postgres\_enable\_high\_availability) | Boolean to enable `ZoneRedundant` high availability with PostgreSQL database. | `bool` | `false` | no |
| <a name="input_postgres_geo_backup_keyvault_key_id"></a> [postgres\_geo\_backup\_keyvault\_key\_id](#input\_postgres\_geo\_backup\_keyvault\_key\_id) | ID of the Key Vault key to use for customer-managed key (CMK) encryption of PostgreSQL Flexible Server geo-redundant backups. This key must be in the same region as the geo-redundant backup. | `string` | `null` | no |
| <a name="input_postgres_geo_backup_user_assigned_identity_id"></a> [postgres\_geo\_backup\_user\_assigned\_identity\_id](#input\_postgres\_geo\_backup\_user\_assigned\_identity\_id) | ID of the User-Assigned Identity to use for customer-managed key (CMK) encryption of PostgreSQL Flexible Server geo-redundant backups. This identity must have 'Get', 'WrapKey', and 'UnwrapKey' permissions to the Key Vault. | `string` | `null` | no |
| <a name="input_postgres_geo_redundant_backup_enabled"></a> [postgres\_geo\_redundant\_backup\_enabled](#input\_postgres\_geo\_redundant\_backup\_enabled) | Boolean to enable PostreSQL geo-redundant backup configuration in paired Azure region. | `bool` | `true` | no |
| <a name="input_postgres_maintenance_window"></a> [postgres\_maintenance\_window](#input\_postgres\_maintenance\_window) | Map of maintenance window settings for PostgreSQL Flexible Server. | `map(number)` | <pre>{<br/>  "day_of_week": 0,<br/>  "start_hour": 0,<br/>  "start_minute": 0<br/>}</pre> | no |
| <a name="input_postgres_primary_availability_zone"></a> [postgres\_primary\_availability\_zone](#input\_postgres\_primary\_availability\_zone) | Number for the availability zone for the primary PostgreSQL Flexible Server instance to reside in. | `number` | `1` | no |
| <a name="input_postgres_secondary_availability_zone"></a> [postgres\_secondary\_availability\_zone](#input\_postgres\_secondary\_availability\_zone) | Number for the availability zone for the standby PostgreSQL Flexible Server instance to reside in. | `number` | `2` | no |
| <a name="input_postgres_sku"></a> [postgres\_sku](#input\_postgres\_sku) | PostgreSQL database SKU. | `string` | `"GP_Standard_D4ds_v4"` | no |
| <a name="input_postgres_source_server_id"></a> [postgres\_source\_server\_id](#input\_postgres\_source\_server\_id) | ID of the source PostgreSQL Flexible Server to replicate from. Only valid when `is_secondary_region` is `true` and `postgres_create_mode` is `Replica`. | `string` | `null` | no |
| <a name="input_postgres_storage_mb"></a> [postgres\_storage\_mb](#input\_postgres\_storage\_mb) | Storage capacity of PostgreSQL Flexible Server (unit is megabytes). | `number` | `65536` | no |
| <a name="input_postgres_version"></a> [postgres\_version](#input\_postgres\_version) | PostgreSQL database version. | `number` | `15` | no |
| <a name="input_private_dns_zone_name"></a> [private\_dns\_zone\_name](#input\_private\_dns\_zone\_name) | Name of existing private Azure DNS zone to create DNS record in. Required when `create_tfe_private_dns_record` is `true`. | `string` | `null` | no |
| <a name="input_private_dns_zone_rg_name"></a> [private\_dns\_zone\_rg\_name](#input\_private\_dns\_zone\_rg\_name) | Name of Resource Group where `private_dns_zone_name` resides. Required when `create_tfe_private_dns_record` is `true`. | `string` | `null` | no |
| <a name="input_public_dns_zone_name"></a> [public\_dns\_zone\_name](#input\_public\_dns\_zone\_name) | Name of existing public Azure DNS zone to create DNS record in. Required when `create_tfe_public_dns_record` is `true`. | `string` | `null` | no |
| <a name="input_public_dns_zone_rg_name"></a> [public\_dns\_zone\_rg\_name](#input\_public\_dns\_zone\_rg\_name) | Name of Resource Group where `public_dns_zone_name` resides. Required when `public_dns_zone_name` is not `null`. | `string` | `null` | no |
| <a name="input_redis_capacity"></a> [redis\_capacity](#input\_redis\_capacity) | The size of the Redis cache to deploy. Valid values for a SKU family of C (Basic/Standard) are 0, 1, 2, 3, 4, 5, 6, and for P (Premium) family are 1, 2, 3, 4. | `number` | `1` | no |
| <a name="input_redis_family"></a> [redis\_family](#input\_redis\_family) | The SKU family/pricing group to use. Valid values are C (for Basic/Standard SKU family) and P (for Premium). | `string` | `"P"` | no |
| <a name="input_redis_min_tls_version"></a> [redis\_min\_tls\_version](#input\_redis\_min\_tls\_version) | Minimum TLS version to use with Redis cache. | `string` | `"1.2"` | no |
| <a name="input_redis_non_ssl_port_enabled"></a> [redis\_non\_ssl\_port\_enabled](#input\_redis\_non\_ssl\_port\_enabled) | Boolean to enable non-SSL port 6379 for Redis cache. | `bool` | `false` | no |
| <a name="input_redis_sku_name"></a> [redis\_sku\_name](#input\_redis\_sku\_name) | Which SKU of Redis to use. Options are 'Basic', 'Standard', or 'Premium'. | `string` | `"Premium"` | no |
| <a name="input_redis_subnet_id"></a> [redis\_subnet\_id](#input\_redis\_subnet\_id) | Subnet ID for Redis cache. | `string` | `null` | no |
| <a name="input_redis_version"></a> [redis\_version](#input\_redis\_version) | Redis cache version. Only the major version is needed. | `number` | `6` | no |
| <a name="input_secondary_vm_subnet_id"></a> [secondary\_vm\_subnet\_id](#input\_secondary\_vm\_subnet\_id) | VM subnet ID of existing TFE virtual machine scaleset (VMSS) in secondary region. Used to allow TFE VMs in secondary region access to TFE storage account in primary region. | `string` | `null` | no |
| <a name="input_storage_account_blob_change_feed_enabled"></a> [storage\_account\_blob\_change\_feed\_enabled](#input\_storage\_account\_blob\_change\_feed\_enabled) | Boolean to enable blob change feed for the TFE Storage Account. | `bool` | `false` | no |
| <a name="input_storage_account_blob_versioning_enabled"></a> [storage\_account\_blob\_versioning\_enabled](#input\_storage\_account\_blob\_versioning\_enabled) | Boolean to enable blob versioning for the TFE Storage Account. | `bool` | `false` | no |
| <a name="input_storage_account_cmk_keyvault_id"></a> [storage\_account\_cmk\_keyvault\_id](#input\_storage\_account\_cmk\_keyvault\_id) | ID of the Key Vault containing the customer-managed key (CMK) for encrypting the TFE Storage Account. | `string` | `null` | no |
| <a name="input_storage_account_cmk_keyvault_key_id"></a> [storage\_account\_cmk\_keyvault\_key\_id](#input\_storage\_account\_cmk\_keyvault\_key\_id) | ID of the customer-managed key (CMK) within Key Vault for encrypting the TFE Storage Account. | `string` | `null` | no |
| <a name="input_storage_account_ip_allow"></a> [storage\_account\_ip\_allow](#input\_storage\_account\_ip\_allow) | List of IP addresses allowed to access TFE Storage Account. Set this to the IP address that you are running Terraform from to deploy this module to avoid a 403 error from Azure when creating the storage container. | `list(string)` | `[]` | no |
| <a name="input_storage_account_public_network_access_enabled"></a> [storage\_account\_public\_network\_access\_enabled](#input\_storage\_account\_public\_network\_access\_enabled) | Boolean to enable public network access to Azure Blob Storage Account. Needs to be `true` for initial deployment. Optionally set to `false` after initial deployment. | `bool` | `true` | no |
| <a name="input_storage_account_replication_type"></a> [storage\_account\_replication\_type](#input\_storage\_account\_replication\_type) | Type of replication to use for TFE Storage Account. | `string` | `"GRS"` | no |
| <a name="input_tfe_capacity_concurrency"></a> [tfe\_capacity\_concurrency](#input\_tfe\_capacity\_concurrency) | Number of concurrent runs TFE can handle. | `number` | `10` | no |
| <a name="input_tfe_capacity_cpu"></a> [tfe\_capacity\_cpu](#input\_tfe\_capacity\_cpu) | Number of CPU cores for TFE. | `number` | `0` | no |
| <a name="input_tfe_capacity_memory"></a> [tfe\_capacity\_memory](#input\_tfe\_capacity\_memory) | Amount of memory in MB for TFE. | `number` | `2048` | no |
| <a name="input_tfe_database_name"></a> [tfe\_database\_name](#input\_tfe\_database\_name) | PostgreSQL database name for TFE. | `string` | `"tfe"` | no |
| <a name="input_tfe_database_parameters"></a> [tfe\_database\_parameters](#input\_tfe\_database\_parameters) | PostgreSQL server parameters for the connection URI. Used to configure the PostgreSQL connection. | `string` | `"sslmode=require"` | no |
| <a name="input_tfe_hairpin_addressing"></a> [tfe\_hairpin\_addressing](#input\_tfe\_hairpin\_addressing) | Boolean to enable hairpin addressing for layer 4 load balancer with loopback prevention. Must be `true` when `lb_is_internal` is `true`. | `bool` | `true` | no |
| <a name="input_tfe_http_port"></a> [tfe\_http\_port](#input\_tfe\_http\_port) | HTTP port for TFE application containers to listen on. | `number` | `8080` | no |
| <a name="input_tfe_https_port"></a> [tfe\_https\_port](#input\_tfe\_https\_port) | HTTPS port for TFE application containers to listen on. | `number` | `8443` | no |
| <a name="input_tfe_image_name"></a> [tfe\_image\_name](#input\_tfe\_image\_name) | Name of the TFE container image. Only change this if you are hosting the TFE container image in your own custom repository. | `string` | `"hashicorp/terraform-enterprise"` | no |
| <a name="input_tfe_image_repository_password"></a> [tfe\_image\_repository\_password](#input\_tfe\_image\_repository\_password) | Password for container registry where TFE container image is hosted. Only set this if you are hosting the TFE container image in your own custom repository. | `string` | `null` | no |
| <a name="input_tfe_image_repository_url"></a> [tfe\_image\_repository\_url](#input\_tfe\_image\_repository\_url) | Repository for the TFE image. Only change this if you are hosting the TFE container image in your own custom repository. | `string` | `"images.releases.hashicorp.com"` | no |
| <a name="input_tfe_image_repository_username"></a> [tfe\_image\_repository\_username](#input\_tfe\_image\_repository\_username) | Username for container registry where TFE container image is hosted. Only change this if you are hosting the TFE container image in your own custom repository. | `string` | `"terraform"` | no |
| <a name="input_tfe_image_tag"></a> [tfe\_image\_tag](#input\_tfe\_image\_tag) | Tag for the TFE container image. This represents the version of TFE to deploy. | `string` | `"v202502-1"` | no |
| <a name="input_tfe_license_reporting_opt_out"></a> [tfe\_license\_reporting\_opt\_out](#input\_tfe\_license\_reporting\_opt\_out) | Boolean to opt out of license reporting. | `bool` | `false` | no |
| <a name="input_tfe_log_forwarding_enabled"></a> [tfe\_log\_forwarding\_enabled](#input\_tfe\_log\_forwarding\_enabled) | Boolean to enable TFE log forwarding feature. | `bool` | `false` | no |
| <a name="input_tfe_metrics_enable"></a> [tfe\_metrics\_enable](#input\_tfe\_metrics\_enable) | Boolean to enable metrics. | `bool` | `false` | no |
| <a name="input_tfe_metrics_http_port"></a> [tfe\_metrics\_http\_port](#input\_tfe\_metrics\_http\_port) | HTTP port for TFE metrics endpoint. | `number` | `9090` | no |
| <a name="input_tfe_metrics_https_port"></a> [tfe\_metrics\_https\_port](#input\_tfe\_metrics\_https\_port) | HTTPS port for TFE metrics endpoint. | `number` | `9091` | no |
| <a name="input_tfe_object_storage_azure_use_msi"></a> [tfe\_object\_storage\_azure\_use\_msi](#input\_tfe\_object\_storage\_azure\_use\_msi) | Boolean to use a User-Assigned Identity (MSI) for TFE blob storage account authentication rather than a storage account key. | `bool` | `true` | no |
| <a name="input_tfe_operational_mode"></a> [tfe\_operational\_mode](#input\_tfe\_operational\_mode) | [Operational mode](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/operation-modes) for TFE. Valid values are `active-active` or `external`. | `string` | `"active-active"` | no |
| <a name="input_tfe_primary_resource_group_name"></a> [tfe\_primary\_resource\_group\_name](#input\_tfe\_primary\_resource\_group\_name) | Name of existing resource group of TFE deployment in primary region. Only set when `is_secondary_region` is `true`. | `string` | `null` | no |
| <a name="input_tfe_primary_storage_account_name"></a> [tfe\_primary\_storage\_account\_name](#input\_tfe\_primary\_storage\_account\_name) | Name of existing TFE storage account in primary region. Only set when `is_secondary_region` is `true`. | `string` | `null` | no |
| <a name="input_tfe_primary_storage_container_name"></a> [tfe\_primary\_storage\_container\_name](#input\_tfe\_primary\_storage\_container\_name) | Name of existing TFE storage container (within TFE storage account) in primary region. Only set when `is_secondary_region` is `true`. | `string` | `null` | no |
| <a name="input_tfe_redis_use_auth"></a> [tfe\_redis\_use\_auth](#input\_tfe\_redis\_use\_auth) | Boolean to enable authentication to the Redis cache. | `bool` | `true` | no |
| <a name="input_tfe_redis_use_tls"></a> [tfe\_redis\_use\_tls](#input\_tfe\_redis\_use\_tls) | Boolean to enable TLS for the Redis cache. | `bool` | `true` | no |
| <a name="input_tfe_run_pipeline_docker_network"></a> [tfe\_run\_pipeline\_docker\_network](#input\_tfe\_run\_pipeline\_docker\_network) | Docker network where the containers that execute Terraform runs will be created. The network must already exist, it will not be created automatically. Leave as `null` to use the default network. | `string` | `null` | no |
| <a name="input_tfe_run_pipeline_image"></a> [tfe\_run\_pipeline\_image](#input\_tfe\_run\_pipeline\_image) | Name of the Docker image to use for the run pipeline driver. | `string` | `null` | no |
| <a name="input_tfe_tls_enforce"></a> [tfe\_tls\_enforce](#input\_tfe\_tls\_enforce) | Boolean to enforce TLS, Strict-Transport-Security headers, and secure cookies within TFE. | `bool` | `false` | no |
| <a name="input_tfe_vault_disable_mlock"></a> [tfe\_vault\_disable\_mlock](#input\_tfe\_vault\_disable\_mlock) | Boolean to disable mlock for internal Vault. | `bool` | `false` | no |
| <a name="input_vm_admin_username"></a> [vm\_admin\_username](#input\_vm\_admin\_username) | Admin username for VMs in VMSS. | `string` | `"tfeadmin"` | no |
| <a name="input_vm_custom_image_name"></a> [vm\_custom\_image\_name](#input\_vm\_custom\_image\_name) | Name of custom VM image to use for VMSS. If not using a custom image, leave this blank. | `string` | `null` | no |
| <a name="input_vm_custom_image_rg_name"></a> [vm\_custom\_image\_rg\_name](#input\_vm\_custom\_image\_rg\_name) | Name of Resource Group where `vm_custom_image_name` image resides. Only valid if `vm_custom_image_name` is not `null`. | `string` | `null` | no |
| <a name="input_vm_disk_encryption_set_name"></a> [vm\_disk\_encryption\_set\_name](#input\_vm\_disk\_encryption\_set\_name) | Name of Disk Encryption Set to use for VMSS. | `string` | `null` | no |
| <a name="input_vm_disk_encryption_set_rg"></a> [vm\_disk\_encryption\_set\_rg](#input\_vm\_disk\_encryption\_set\_rg) | Name of Resource Group where the Disk Encryption Set to use for VMSS exists. | `string` | `null` | no |
| <a name="input_vm_enable_boot_diagnostics"></a> [vm\_enable\_boot\_diagnostics](#input\_vm\_enable\_boot\_diagnostics) | Boolean to enable boot diagnostics for VMSS. | `bool` | `false` | no |
| <a name="input_vm_os_image"></a> [vm\_os\_image](#input\_vm\_os\_image) | The OS image to use for the VM. Options are: redhat8, redhat9, ubuntu2204, ubuntu2404. | `string` | `"redhat9"` | no |
| <a name="input_vm_sku"></a> [vm\_sku](#input\_vm\_sku) | SKU for VM size for the VMSS. | `string` | `"Standard_D4s_v4"` | no |
| <a name="input_vm_ssh_public_key"></a> [vm\_ssh\_public\_key](#input\_vm\_ssh\_public\_key) | SSH public key for VMs in VMSS. | `string` | `null` | no |
| <a name="input_vmss_instance_count"></a> [vmss\_instance\_count](#input\_vmss\_instance\_count) | Number of VM instances to run in the Virtual Machine Scaleset (VMSS). | `number` | `1` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_tfe_database_host"></a> [tfe\_database\_host](#output\_tfe\_database\_host) | FQDN and port of PostgreSQL Flexible Server. |
| <a name="output_tfe_database_name"></a> [tfe\_database\_name](#output\_tfe\_database\_name) | Name of PostgreSQL Flexible Server database. |
| <a name="output_tfe_object_storage_azure_account_name"></a> [tfe\_object\_storage\_azure\_account\_name](#output\_tfe\_object\_storage\_azure\_account\_name) | Name of primary TFE Azure Storage Account. |
| <a name="output_tfe_object_storage_azure_container_name"></a> [tfe\_object\_storage\_azure\_container\_name](#output\_tfe\_object\_storage\_azure\_container\_name) | Name of TFE Azure Storage Container. |
| <a name="output_url"></a> [url](#output\_url) | URL of TFE application based on `tfe_fqdn` input. |
<!-- END_TF_DOCS -->
