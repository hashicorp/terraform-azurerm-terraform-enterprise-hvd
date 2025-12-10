# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# Common
#------------------------------------------------------------------------------
variable "create_resource_group" {
  type        = bool
  description = "Boolean to create a new resource group for this TFE deployment."
  default     = true
}

variable "resource_group_name" {
  type        = string
  description = "Name of resource group for this TFE deployment. Must be an existing resource group if `create_resource_group` is `false`."
}

variable "location" {
  type        = string
  description = "Azure region for this TFE deployment."

  validation {
    condition     = var.is_govcloud_region ? contains(["usgovvirginia", "usgovtexas", "usgovarizona", "usdodcentral", "usdodeast"], var.location) : contains(["eastus", "westus", "centralus", "eastus2", "westus2", "westeurope", "northeurope", "southeastasia", "eastasia", "australiaeast", "australiasoutheast", "uksouth", "ukwest", "canadacentral", "canadaeast", "southindia", "centralindia", "westindia", "japaneast", "japanwest", "koreacentral", "koreasouth", "francecentral", "southafricanorth", "uaenorth", "brazilsouth", "switzerlandnorth", "germanywestcentral", "norwayeast", "westcentralus"], var.location)
    error_message = var.is_govcloud_region ? "Value is not a valid Azure Government region." : "Value is not a valid Azure region."
  }
}

variable "friendly_name_prefix" {
  type        = string
  description = "Friendly name prefix used for uniquely naming all Azure resources for this deployment. Most commonly set to either an environment (e.g. 'sandbox', 'prod'), a team name, or a project name."

  validation {
    condition     = can(regex("^[[:alnum:]]+$", var.friendly_name_prefix)) && length(var.friendly_name_prefix) < 13
    error_message = "Value can only contain alphanumeric characters and must be less than 13 characters."
  }

  validation {
    condition     = !strcontains(lower(var.friendly_name_prefix), "tfe")
    error_message = "Value must not contain the substring 'tfe' to avoid redundancy in resource naming."
  }
}

variable "common_tags" {
  type        = map(string)
  description = "Map of common tags for taggable Azure resources."
  default     = {}
}

variable "availability_zones" {
  type        = set(string)
  description = "List of Azure availability zones to spread TFE resources across."
  default     = ["1", "2", "3"]

  validation {
    condition     = alltrue([for az in var.availability_zones : contains(["1", "2", "3"], az)])
    error_message = "Availability zone must be one of, or a combination of '1', '2', '3'."
  }
}

variable "is_secondary_region" {
  type        = bool
  description = "Boolean indicating whether this TFE deployment is for 'primary' region or 'secondary' region."
  default     = false
}

variable "is_govcloud_region" {
  type        = bool
  description = "Boolean indicating whether this TFE deployment is in an Azure Government Cloud region."
  default     = false
}

variable "tfe_primary_resource_group_name" {
  type        = string
  description = "Name of existing resource group of TFE deployment in primary region. Only set when `is_secondary_region` is `true`. "
  default     = null

  validation {
    condition     = var.is_secondary_region ? var.tfe_primary_resource_group_name != null : true
    error_message = "Value must be set when `is_secondary_region` is `true`."
  }

  validation {
    condition     = !var.is_secondary_region ? var.tfe_primary_resource_group_name == null : true
    error_message = "Value must be `null` when `is_secondary_region` is `false`."
  }
}

#------------------------------------------------------------------------------
# Bootstrap
#------------------------------------------------------------------------------
variable "bootstrap_keyvault_name" {
  type        = string
  description = "Name of the 'bootstrap' Key Vault to use for bootstrapping TFE deployment."
}

variable "bootstrap_keyvault_rg_name" {
  type        = string
  description = "Name of the Resource Group where the 'bootstrap' Key Vault resides."
}

variable "tfe_license_keyvault_secret_id" {
  type        = string
  description = "ID of Key Vault secret containing TFE license."
}

variable "tfe_tls_cert_keyvault_secret_id" {
  type        = string
  description = "ID of Key Vault secret containing TFE TLS certificate."
}

variable "tfe_tls_privkey_keyvault_secret_id" {
  type        = string
  description = "ID of Key Vault secret containing TFE TLS private key."
}

variable "tfe_tls_ca_bundle_keyvault_secret_id" {
  type        = string
  description = "ID of Key Vault secret containing TFE TLS custom CA bundle."
}

variable "tfe_encryption_password_keyvault_secret_id" {
  type        = string
  description = "ID of Key Vault secret containing TFE encryption password."
}

variable "tfe_image_repository_url" {
  type        = string
  description = "Repository for the TFE image. Only change this if you are hosting the TFE container image in your own custom repository."
  default     = "images.releases.hashicorp.com"
}

variable "tfe_image_name" {
  type        = string
  description = "Name of the TFE container image. Only change this if you are hosting the TFE container image in your own custom repository."
  default     = "hashicorp/terraform-enterprise"
}

variable "tfe_image_tag" {
  type        = string
  description = "Tag for the TFE container image. This represents the version of TFE to deploy."
  default     = "v202502-1"
}

variable "tfe_image_repository_username" {
  type        = string
  description = "Username for container registry where TFE container image is hosted. Only change this if you are hosting the TFE container image in your own custom repository."
  default     = "terraform"
}

variable "tfe_image_repository_password" {
  type        = string
  description = "Password for container registry where TFE container image is hosted. Only set this if you are hosting the TFE container image in your own custom repository."
  default     = null

  validation {
    condition     = var.tfe_image_repository_url == "images.releases.hashicorp.com" ? var.tfe_image_repository_password == null : true
    error_message = "Value must be `null` when `tfe_image_repository_url` is set to the default of `images.releases.hashicorp.com` (the TFE license is the password)."
  }
}

#------------------------------------------------------------------------------
# TFE configuration settings
#------------------------------------------------------------------------------
variable "tfe_fqdn" {
  type        = string
  description = "Fully qualified domain name of TFE instance. This name should resolve to the load balancer IP address and will be what clients use to access TFE."
}

variable "tfe_capacity_concurrency" {
  type        = number
  description = "Number of concurrent runs TFE can handle."
  default     = 10
}

variable "tfe_capacity_cpu" {
  type        = number
  description = "Number of CPU cores for TFE."
  default     = 0
}

variable "tfe_capacity_memory" {
  type        = number
  description = "Amount of memory in MB for TFE."
  default     = 2048
}

variable "tfe_license_reporting_opt_out" {
  type        = bool
  description = "Boolean to opt out of license reporting."
  default     = false
}

variable "tfe_operational_mode" {
  type        = string
  description = "[Operational mode](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/operation-modes) for TFE. Valid values are `active-active` or `external`."
  default     = "active-active"

  validation {
    condition     = var.tfe_operational_mode == "active-active" || var.tfe_operational_mode == "external"
    error_message = "Value must be `active-active` or `external`."
  }
}

variable "tfe_http_port" {
  type        = number
  description = "HTTP port for TFE application containers to listen on."
  default     = 8080

  validation {
    condition     = var.container_runtime == "podman" ? var.tfe_http_port != 80 : true
    error_message = "Value must not be `80` when `container_runtime` is `podman` to avoid conflicts."
  }
}

variable "tfe_https_port" {
  type        = number
  description = "HTTPS port for TFE application containers to listen on."
  default     = 8443

  validation {
    condition     = var.container_runtime == "podman" ? var.tfe_https_port != 443 : true
    error_message = "Value must not be `80` when `container_runtime` is `podman` to avoid conflicts."
  }
}

variable "tfe_run_pipeline_image" {
  type        = string
  description = "Name of the Docker image to use for the run pipeline driver."
  default     = null
}

variable "tfe_metrics_enable" {
  type        = bool
  description = "Boolean to enable metrics."
  default     = false
}

variable "tfe_metrics_http_port" {
  type        = number
  description = "HTTP port for TFE metrics endpoint."
  default     = 9090
}

variable "tfe_metrics_https_port" {
  type        = number
  description = "HTTPS port for TFE metrics endpoint."
  default     = 9091
}

variable "tfe_tls_enforce" {
  type        = bool
  description = "Boolean to enforce TLS, Strict-Transport-Security headers, and secure cookies within TFE."
  default     = false
}

variable "tfe_vault_disable_mlock" {
  type        = bool
  description = "Boolean to disable mlock for internal Vault."
  default     = false
}

variable "tfe_hairpin_addressing" {
  type        = bool
  description = "Boolean to enable hairpin addressing for layer 4 load balancer with loopback prevention. Must be `true` when `lb_is_internal` is `true`."
  default     = true

  validation {
    condition     = var.lb_is_internal ? var.tfe_hairpin_addressing : true
    error_message = "Value must be `true` when `lb_type` is `nlb` and `lb_is_internal` is `true`."
  }
}

variable "tfe_run_pipeline_docker_network" {
  type        = string
  description = "Docker network where the containers that execute Terraform runs will be created. The network must already exist, it will not be created automatically. Leave as `null` to use the default network."
  default     = null
}

#------------------------------------------------------------------------------
# Networking
#------------------------------------------------------------------------------
variable "vnet_id" {
  type        = string
  description = "ID of VNet where TFE will be deployed."
}

variable "create_lb" {
  type        = bool
  description = "Boolean to create an Azure Load Balancer for TFE."
  default     = true
}

variable "lb_subnet_id" {
  type        = string
  description = "Subnet ID for Azure load balancer."
  default     = null
}

variable "lb_is_internal" {
  type        = bool
  description = "Boolean to create an internal or external Azure Load Balancer for TFE."
  default     = true
}

variable "lb_private_ip" {
  type        = string
  description = "Private IP address for internal Azure Load Balancer. Only valid when `lb_is_internal` is `true`."
  default     = null
}

variable "vm_subnet_id" {
  type        = string
  description = "Subnet ID for Virtual Machine Scaleset (VMSS)."
}

variable "db_subnet_id" {
  type        = string
  description = "Subnet ID for PostgreSQL database."
}

variable "redis_subnet_id" {
  type        = string
  description = "Subnet ID for Redis cache."
  default     = null
}

variable "secondary_vm_subnet_id" {
  type        = string
  description = "VM subnet ID of existing TFE virtual machine scaleset (VMSS) in secondary region. Used to allow TFE VMs in secondary region access to TFE storage account in primary region."
  default     = null

  validation {
    condition     = var.is_secondary_region ? var.secondary_vm_subnet_id == null : true
    error_message = "Value must be `null` when `is_secondary_region` is `true`, as the TFE storage account only exists in the primary region."
  }
}

#------------------------------------------------------------------------------
# DNS
#------------------------------------------------------------------------------
variable "create_tfe_public_dns_record" {
  type        = bool
  description = "Boolean to create a DNS record for TFE in a public Azure DNS zone. A `public_dns_zone_name` must also be provided when `true`."
  default     = false
}

variable "public_dns_zone_name" {
  type        = string
  description = "Name of existing public Azure DNS zone to create DNS record in. Required when `create_tfe_public_dns_record` is `true`."
  default     = null

  validation {
    condition     = var.create_tfe_public_dns_record ? var.public_dns_zone_name != null : true
    error_message = "A value is required when `create_tfe_public_dns_record` is `true`."
  }
}

variable "public_dns_zone_rg_name" {
  type        = string
  description = "Name of Resource Group where `public_dns_zone_name` resides. Required when `public_dns_zone_name` is not `null`."
  default     = null

  validation {
    condition     = var.public_dns_zone_name != null ? var.public_dns_zone_rg_name != null : true
    error_message = "A value is required when `public_dns_zone_name` is not `null`."
  }
}

variable "create_tfe_private_dns_record" {
  type        = bool
  description = "Boolean to create a DNS record for TFE in a private Azure DNS zone. A `private_dns_zone_name` must also be provided when `true`."
  default     = false
}

variable "private_dns_zone_name" {
  type        = string
  description = "Name of existing private Azure DNS zone to create DNS record in. Required when `create_tfe_private_dns_record` is `true`."
  default     = null

  validation {
    condition     = var.create_tfe_private_dns_record ? var.private_dns_zone_name != null : true
    error_message = "A value is required when `create_tfe_private_dns_record` is `true`."
  }
}

variable "private_dns_zone_rg_name" {
  type        = string
  description = "Name of Resource Group where `private_dns_zone_name` resides. Required when `create_tfe_private_dns_record` is `true`."
  default     = null

  validation {
    condition     = var.private_dns_zone_name != null ? var.private_dns_zone_rg_name != null : true
    error_message = "A value is required when `private_dns_zone_name` is not `null`."
  }
}

#------------------------------------------------------------------------------
# Compute
#------------------------------------------------------------------------------
variable "vmss_instance_count" {
  type        = number
  description = "Number of VM instances to run in the Virtual Machine Scaleset (VMSS)."
  default     = 1
}

variable "vm_sku" {
  type        = string
  description = "SKU for VM size for the VMSS."
  default     = "Standard_D4s_v4"

  validation {
    condition     = can(regex("^[A-Za-z0-9_]+$", var.vm_sku))
    error_message = "Value can only contain alphanumeric characters and underscores."
  }
}

variable "vm_admin_username" {
  type        = string
  description = "Admin username for VMs in VMSS."
  default     = "tfeadmin"
}

variable "vm_ssh_public_key" {
  type        = string
  description = "SSH public key for VMs in VMSS."
  default     = null
}

variable "vm_os_image" {
  description = "The OS image to use for the VM. Options are: redhat8, redhat9, ubuntu2204, ubuntu2404."
  type        = string
  default     = "redhat9"

  validation {
    condition     = contains(["redhat8", "redhat9", "ubuntu2204", "ubuntu2404"], var.vm_os_image)
    error_message = "Value must be one of 'redhat8', 'redhat9', 'ubuntu2204', or 'ubuntu2404'."
  }
}

variable "vm_custom_image_name" {
  type        = string
  description = "Name of custom VM image to use for VMSS. If not using a custom image, leave this blank."
  default     = null
}

variable "vm_custom_image_rg_name" {
  type        = string
  description = "Name of Resource Group where `vm_custom_image_name` image resides. Only valid if `vm_custom_image_name` is not `null`."
  default     = null

  validation {
    condition     = var.vm_custom_image_name != null ? var.vm_custom_image_rg_name != null : true
    error_message = "A value is required when `vm_custom_image_name` is not `null`."
  }
}

variable "custom_tfe_startup_script_template" {
  type        = string
  description = "Name of custom TFE startup script template file. File must exist within a directory named `./templates` within your current working directory."
  default     = null

  validation {
    condition     = var.custom_tfe_startup_script_template != null ? fileexists("${path.cwd}/templates/${var.custom_tfe_startup_script_template}") : true
    error_message = "File not found. Ensure the file exists within a directory named `./templates` within your current working directory."
  }
}

variable "container_runtime" {
  type        = string
  description = "Value of container runtime to use for TFE deployment. For Redhat, the default is `podman`, but optionally `docker` can be used. For Ubuntu, the default is `docker`."

  validation {
    condition = (
      (contains(["redhat8", "redhat9"], var.vm_os_image) && contains(["docker", "podman"], var.container_runtime)) ||
      (contains(["ubuntu2204", "ubuntu2404"], var.vm_os_image) && var.container_runtime == "docker")
    )
    error_message = "For Redhat, the container runtime can be 'docker' or 'podman'. For Ubuntu, the container runtime must be 'docker'."
  }
}

variable "docker_version" {
  type        = string
  description = "Version of Docker to install on TFE VMSS."
  default     = "28.0.1"
}

variable "vm_disk_encryption_set_name" {
  type        = string
  description = "Name of Disk Encryption Set to use for VMSS."
  default     = null
}

variable "vm_disk_encryption_set_rg" {
  type        = string
  description = "Name of Resource Group where the Disk Encryption Set to use for VMSS exists."
  default     = null
}

variable "vm_enable_boot_diagnostics" {
  type        = bool
  description = "Boolean to enable boot diagnostics for VMSS."
  default     = false
}

#------------------------------------------------------------------------------
# PostgreSQL (database)
#------------------------------------------------------------------------------
variable "tfe_database_password_keyvault_secret_name" {
  type        = string
  description = "Name of the secret in the Key Vault that contains the TFE database password."
}

variable "postgres_version" {
  type        = number
  description = "PostgreSQL database version."
  default     = 15
}

variable "postgres_sku" {
  type        = string
  description = "PostgreSQL database SKU."
  default     = "GP_Standard_D4ds_v4"
}

variable "postgres_storage_mb" {
  type        = number
  description = "Storage capacity of PostgreSQL Flexible Server (unit is megabytes)."
  default     = 65536
}

variable "postgres_administrator_login" {
  type        = string
  description = "Username for administrator login of PostreSQL database."
  default     = "tfeadmin"
}

variable "postgres_backup_retention_days" {
  type        = number
  description = "Number of days to retain backups of PostgreSQL Flexible Server."
  default     = 35
}

variable "postgres_create_mode" {
  type        = string
  description = "Determines if the PostgreSQL Flexible Server is being created as a new server or as a replica."
  default     = "Default"

  validation {
    condition     = anytrue([var.postgres_create_mode == "Default", var.postgres_create_mode == "Replica"])
    error_message = "Value must be `Default` or `Replica`."
  }
}

variable "tfe_database_name" {
  type        = string
  description = "PostgreSQL database name for TFE."
  default     = "tfe"
}

variable "tfe_database_parameters" {
  type        = string
  description = "PostgreSQL server parameters for the connection URI. Used to configure the PostgreSQL connection."
  default     = "sslmode=require"
}

variable "create_postgres_private_endpoint" {
  type        = bool
  description = "Boolean to create a private endpoint and private DNS zone for PostgreSQL Flexible Server."
  default     = true
}

variable "postgres_enable_high_availability" {
  type        = bool
  description = "Boolean to enable `ZoneRedundant` high availability with PostgreSQL database."
  default     = false
}

variable "postgres_geo_redundant_backup_enabled" {
  type        = bool
  description = "Boolean to enable PostreSQL geo-redundant backup configuration in paired Azure region."
  default     = true
}

variable "postgres_primary_availability_zone" {
  type        = number
  description = "Number for the availability zone for the primary PostgreSQL Flexible Server instance to reside in."
  default     = 1
}

variable "postgres_secondary_availability_zone" {
  type        = number
  description = "Number for the availability zone for the standby PostgreSQL Flexible Server instance to reside in."
  default     = 2
}

variable "postgres_maintenance_window" {
  type        = map(number)
  description = "Map of maintenance window settings for PostgreSQL Flexible Server."
  default = {
    day_of_week  = 0
    start_hour   = 0
    start_minute = 0
  }
}

variable "postgres_cmk_keyvault_key_id" {
  type        = string
  description = "ID of the Key Vault key to use for customer-managed key (CMK) encryption of PostgreSQL Flexible Server database."
  default     = null
}

variable "postgres_cmk_keyvault_id" {
  type        = string
  description = "ID of the Key Vault containing the customer-managed key (CMK) for encrypting the PostgreSQL Flexible Server database."
  default     = null
}

variable "postgres_geo_backup_keyvault_key_id" {
  type        = string
  description = "ID of the Key Vault key to use for customer-managed key (CMK) encryption of PostgreSQL Flexible Server geo-redundant backups. This key must be in the same region as the geo-redundant backup."
  default     = null
}

variable "postgres_geo_backup_user_assigned_identity_id" {
  type        = string
  description = "ID of the User-Assigned Identity to use for customer-managed key (CMK) encryption of PostgreSQL Flexible Server geo-redundant backups. This identity must have 'Get', 'WrapKey', and 'UnwrapKey' permissions to the Key Vault."
  default     = null
}

variable "postgres_source_server_id" {
  type        = string
  description = "ID of the source PostgreSQL Flexible Server to replicate from. Only valid when `is_secondary_region` is `true` and `postgres_create_mode` is `Replica`."
  default     = null

  validation {
    condition     = !var.is_secondary_region ? var.postgres_source_server_id == null : true
    error_message = "Value must be `null` when `is_secondary_region` is `false`."
  }
}

#------------------------------------------------------------------------------
# Storage account (blob storage)
#------------------------------------------------------------------------------
variable "tfe_object_storage_azure_use_msi" {
  type        = bool
  description = "Boolean to use a User-Assigned Identity (MSI) for TFE blob storage account authentication rather than a storage account key."
  default     = true
}

variable "storage_account_public_network_access_enabled" {
  type        = bool
  description = "Boolean to enable public network access to Azure Blob Storage Account. Needs to be `true` for initial deployment. Optionally set to `false` after initial deployment."
  default     = true
}

variable "storage_account_ip_allow" {
  type        = list(string)
  description = "List of IP addresses allowed to access TFE Storage Account. Set this to the IP address that you are running Terraform from to deploy this module to avoid a 403 error from Azure when creating the storage container."
  default     = []
}

variable "storage_account_replication_type" {
  type        = string
  description = "Type of replication to use for TFE Storage Account."
  default     = "GRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.storage_account_replication_type)
    error_message = "Value must be one of 'LRS', 'GRS', 'RAGRS', 'ZRS', 'GZRS', or 'RAGZRS'."
  }
}

variable "create_blob_storage_private_endpoint" {
  type        = bool
  description = "Boolean to create a private endpoint and private DNS zone for TFE Storage Account."
  default     = true
}

variable "storage_account_cmk_keyvault_key_id" {
  type        = string
  description = "ID of the customer-managed key (CMK) within Key Vault for encrypting the TFE Storage Account."
  default     = null
}

variable "storage_account_cmk_keyvault_id" {
  type        = string
  description = "ID of the Key Vault containing the customer-managed key (CMK) for encrypting the TFE Storage Account."
  default     = null
}

variable "storage_account_blob_versioning_enabled" {
  type        = bool
  description = "Boolean to enable blob versioning for the TFE Storage Account."
  default     = false
}

variable "storage_account_blob_change_feed_enabled" {
  type        = bool
  description = "Boolean to enable blob change feed for the TFE Storage Account."
  default     = false
}

variable "tfe_primary_storage_account_name" {
  type        = string
  description = "Name of existing TFE storage account in primary region. Only set when `is_secondary_region` is `true`. "
  default     = null

  validation {
    condition     = var.is_secondary_region ? var.tfe_primary_storage_account_name != null : true
    error_message = "Value is required when `is_secondary_region` is `true`."
  }

  validation {
    condition     = !var.is_secondary_region ? var.tfe_primary_storage_account_name == null : true
    error_message = "Value must be `null` when `is_secondary_region` is `false`."
  }
}

variable "tfe_primary_storage_container_name" {
  type        = string
  description = "Name of existing TFE storage container (within TFE storage account) in primary region. Only set when `is_secondary_region` is `true`."
  default     = null

  validation {
    condition     = var.is_secondary_region ? var.tfe_primary_storage_container_name != null : true
    error_message = "Value is required when `is_secondary_region` is `true`."
  }

  validation {
    condition     = !var.is_secondary_region ? var.tfe_primary_storage_container_name == null : true
    error_message = "Value must be `null` when `is_secondary_region` is `false`."
  }
}

#------------------------------------------------------------------------------
# Redis cache
#------------------------------------------------------------------------------
variable "redis_family" {
  type        = string
  description = "The SKU family/pricing group to use. Valid values are C (for Basic/Standard SKU family) and P (for Premium)."
  default     = "P"

  validation {
    condition     = contains(["C", "P"], var.redis_family)
    error_message = "Supported values are `C` or `P`."
  }
}

variable "redis_capacity" {
  type        = number
  description = "The size of the Redis cache to deploy. Valid values for a SKU family of C (Basic/Standard) are 0, 1, 2, 3, 4, 5, 6, and for P (Premium) family are 1, 2, 3, 4."
  default     = 1

  validation {
    condition     = contains([0, 1, 2, 3, 4, 5, 6], var.redis_capacity)
    error_message = "Valid values for a SKU family of C (Basic/Standard) are 0, 1, 2, 3, 4, 5, 6, and for P (Premium) family are 1, 2, 3, 4."
  }
}

variable "redis_sku_name" {
  type        = string
  description = "Which SKU of Redis to use. Options are 'Basic', 'Standard', or 'Premium'."
  default     = "Premium"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.redis_sku_name)
    error_message = "Supported values are `Basic`, `Standard`, or `Premium`."
  }
}

variable "redis_version" {
  type        = number
  description = "Redis cache version. Only the major version is needed."
  default     = 6
}

variable "tfe_redis_use_auth" {
  type        = bool
  description = "Boolean to enable authentication to the Redis cache."
  default     = true
}

variable "tfe_redis_use_tls" {
  type        = bool
  description = "Boolean to enable TLS for the Redis cache."
  default     = true
}

variable "redis_non_ssl_port_enabled" {
  type        = bool
  description = "Boolean to enable non-SSL port 6379 for Redis cache."
  default     = false
}

variable "redis_min_tls_version" {
  type        = string
  description = "Minimum TLS version to use with Redis cache."
  default     = "1.2"
}

variable "create_redis_private_endpoint" {
  type        = bool
  description = "Boolean to create a private DNS zone and private endpoint for Redis cache."
  default     = true
}

#------------------------------------------------------------------------------
# Log forwarding
#------------------------------------------------------------------------------
variable "tfe_log_forwarding_enabled" {
  type        = bool
  description = "Boolean to enable TFE log forwarding feature."
  default     = false
}

variable "log_fwd_destination_type" {
  type        = string
  description = "Type of log forwarding destination. Valid values are 'log_analytics' or 'custom'."
  default     = "log_analytics"

  validation {
    condition     = contains(["log_analytics", "custom"], var.log_fwd_destination_type)
    error_message = "Supported values are `log_analytics` or `custom`."
  }
}

variable "log_analytics_workspace_name" {
  type        = string
  description = "Name existing Azure Log Analytics Workspace for log forwarding destination. Only valid if `log_fwd_destination_type` is `log_analytics`."
  default     = null

  validation {
    condition     = var.tfe_log_forwarding_enabled && var.log_fwd_destination_type == "log_analytics" ? var.log_analytics_workspace_name != null : true
    error_message = "Value is required when `tfe_log_forwarding_enabled` is `true` and `log_fwd_destination_type` is `log_analytics`."

  }
}

variable "log_analytics_workspace_rg_name" {
  type        = string
  description = "Name of Resource Group where Log Analytics Workspace exists."
  default     = null

  validation {
    condition     = var.log_fwd_destination_type == "log_analytics" && var.log_analytics_workspace_name != null ? var.log_analytics_workspace_rg_name != null : true
    error_message = "Value is required when `log_fwd_destination_type` is `log_analytics` and `log_analytics_workspace_name` is not `null`."
  }
}

variable "custom_fluent_bit_config" {
  type        = string
  description = "Custom Fluent Bit configuration for log forwarding. Only valid if `log_fwd_destination_type` is `custom`."
  default     = null
}
