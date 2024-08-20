# Deployment Customizations

On this page are various deployment customizations and their corresponding input variables that you may set to meet your requirements.

### Storage Account Public Network Access

By default, `storage_account_public_network_access_enabled` is set to `true` to avoid the following error that Azure will throw when attempting to create the `azurerm_storage_container.tfe` resource within the TFE Storage Account:

```
Status=403 Code="AuthorizationFailure" Message="This request is not authorized to perform this operation.
```

>📝 Note: If your client/workstation that you are running Terraform from to deploy TFE is within the same VNet as the TFE VM subnet, then you can you set this value to `false` as you will not receive the 403 error.

Even when `storage_account_public_network_access_enabled` is `true`, this module will configure the Storage Account network rules to only allow access from the specified IP addresses via the input variable `storage_account_ip_allow`, as well as the TFE VM subnet - so it is safe to leave it set to `true` if you are comfortable with that. Therefore, you should set `storage_account_ip_allow` to the IP address(es) of the clients/workstations that you and your team will be running Terraform from to deploy and manage your TFE instance.

```hcl
storage_account_ip_allow = ["<192.168.1.10>", "<192.168.1.11>", "<192.168.1.12>"]
```

After the initial deployment is successful, you may set `storage_account_public_network_access_enabled` to `false` if you prefer. However, if you do so, you should expect a similar 403 authorization error as shown above the next time you run Terraform to manage your TFE deployment from a client/workstation outside of the TFE VNet. Therefore, you will have to log in to the Azure portal and temporarily toggle the public network access setting within the Networking section of the Storage Account to **Enabled from selected virtual networks and IP addresses** before running Terraform again.

### Load Balancer

This module defaults to creating a load balancer (`create_lb = true`) that is internal (`lb_is_internal = true`).

#### Internal Load Balancer with Static (private) IP

When using an internal load balancer you must set the static IP to an available IP address from your TFE load balancer subnet.

```hcl
lb_private_ip = "<10.0.1.20>"
```

#### External Load Balancer with Public IP

Here we must set the following boolean to false, and the module will automatically create a Public IP address resource for the TFE load balancer frontend IP configuration.

```hcl
lb_is_internal = false
```

### DNS

If you have an existing Azure DNS zone (public or private) that you would like this module to create a DNS record within for the TFE FQDN, the following input variables may be set. This is completely optional; you are free to create your own DNS record for the TFE FQDN resolving to the TFE load balancer IP address out-of-band from this module.

#### Azure Private DNS Zone

If your TFE load balancer is internal (`lb_is_internal = true`) and a private, static IP is set (`lb_private_ip = "10.0.1.20"`), then the DNS record should be created in a private zone.

```hcl
create_tfe_private_dns_record = true
private_dns_zone_name         = "<example.com>"
private_dns_zone_rg_name      = "<my-private-dns-zone-resource-group-name>"
```

>📝 Note: Your private DNS zone must have a Virtual Network Link configured with your TFE VNet.

#### Azure Public DNS Zone

If your load balancer is external (`lb_is_internal = false`), the module will automatically create a public IP address for the TFE load balancer, and hence the DNS record should be created in a public zone.

```hcl
create_tfe_public_dns_record  = true
public_dns_zone_name          = "<example.com>"
public_dns_zone_rg_name       = "<my-public-dns-zone-resource-group-name>"
```

### Log Forwarding

The following variables may be set to enable TFE log forwarding (via Fluent Bit). The destinations supported at this time are an Azure Log Analytics Workspace or a custom Fluent Bit configuration, either of which would need to exist as a prerequisite.

#### Log Analytics

```hcl
tfe_log_forwarding_enabled   = true
log_fwd_resource_group_name  = "<my-log-analytics-resource-group-name>"
log_analytics_workspace_name = "<my-log-analytics-workspace-name>"
```

#### Custom

```hcl
tfe_log_forwarding_enabled = true
log_fwd_destination_type   = "custom"
custom_fluent_bit_config   = "<>"
```

### Metrics and Monitoring

The following variables may be set to enable the TFE metrics endpoint(s):

```hcl
tfe_metrics_enable     = true
tfe_metrics_http_port  = 9090
tfe_metrics_https_port = 9091
```

>📝 Note: ensure your have NSG/firwall rules in place to allow `TCP/9090` or `TCP/9091` ingress to your TFE VM subnet.

### Custom VM Image

If a custom VM image is preferred over using a standard marketplace image, the following variables may be set:

```hcl
vm_custom_image_name    = "<my-custom-ubuntu-2204-image>"
vm_custom_image_rg_name = "<my-custom-image-resource-group-name>"
```

### PostgreSQL Customer Managed Key (CMK)

The following variables may be set to configure PostgreSQL Flexible Server with a customer managed key (CMK) for encryption:

```hcl
postgres_cmk_keyvault_id                      = "<key-vault-id-of-tfe-postgres-cmk>"
postgres_cmk_keyvault_key_id                  = "<https://postgres-cmk-identifier>"         # primary region
postgres_geo_backup_keyvault_key_id           = "<https://postgres-cmk-identifier>"         # secondary region
postgres_geo_backup_user_assigned_identity_id = "<user-assigned-msi-id-for-geo-backup-cmk>" # secondary region
```

>📝 Note: `postgres_geo_backup_keyvault_key_id` and `postgres_geo_backup_user_assigned_identity_id` are only needed if `postgres_geo_redundant_backup_enabled` is `true`.

### Storage Account Customer Managed Key (CMK)

The following variables may be set to configure the TFE Blob Storage Account with a customer managed key (CMK) for encryption:

```hcl
storage_account_cmk_keyvault_id     = "<key-vault-id-of-tfe-blob-cmk>"
storage_account_cmk_keyvault_key_id = "<https://my-tfe-blob-cmk-identifier>"
```

### VM Disk Encryption Set

The following variables may be set to configure an existing Disk Encryption Set for the TFE VMSS:

```hcl
vm_disk_encryption_set_name = <"my-disk-encryption-set-name">
vm_disk_encryption_set_rg   = <"my-disk-encryption-set-resource-group-name">
```

>📝 Note: ensure that your Key Vault that contains the key for the Disk Encryption Set has an Access Policy that allows the following key permissions: `Get`, `WrapKey`, and `UnwrapKey`.
