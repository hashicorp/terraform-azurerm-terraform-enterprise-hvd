#------------------------------------------------------------------------------
# Log fowarding - log analytics workspace
#------------------------------------------------------------------------------
data "azurerm_log_analytics_workspace" "logging" {
  count = var.tfe_log_forwarding_enabled && var.log_fwd_destination_type == "log_analytics" ? 1 : 0

  resource_group_name = var.log_analytics_workspace_rg_name == null ? local.resource_group_name : var.log_analytics_workspace_rg_name
  name                = var.log_analytics_workspace_name
}

locals {
  // Azure log analytics workspace destination
  fluent_bit_log_analytics_args = {
    log_analytics_workspace_id = var.tfe_log_forwarding_enabled && var.log_fwd_destination_type == "log_analytics" ? data.azurerm_log_analytics_workspace.logging[0].workspace_id : null
    log_analytics_access_key   = var.tfe_log_forwarding_enabled && var.log_fwd_destination_type == "log_analytics" ? data.azurerm_log_analytics_workspace.logging[0].primary_shared_key : null
  }
  fluent_bit_log_analytics_config = var.tfe_log_forwarding_enabled && var.log_fwd_destination_type == "log_analytics" ? (templatefile("${path.module}/templates/fluent-bit-log-analytics.conf.tpl", local.fluent_bit_log_analytics_args)) : ""

  // Custom destination
  fluent_bit_custom_config = var.tfe_log_forwarding_enabled && var.log_fwd_destination_type == "custom" ? var.custom_fluent_bit_config : ""

  // Final rendered FluentBit config
  fluent_bit_rendered_config = join("", [local.fluent_bit_log_analytics_config, local.fluent_bit_custom_config])
}

#------------------------------------------------------------------------------
# Custom data (cloud-init) script arguments
#------------------------------------------------------------------------------
locals {
  redis_port                           = var.tfe_redis_use_tls ? 6380 : 6379
  tfe_object_storage_azure_account_key = var.is_secondary_region ? data.azurerm_storage_account.tfe[0].primary_access_key : azurerm_storage_account.tfe[0].primary_access_key

  custom_data_args = {
    # Bootstrap
    tfe_license_keyvault_secret_id             = var.tfe_license_keyvault_secret_id
    tfe_tls_cert_keyvault_secret_id            = var.tfe_tls_cert_keyvault_secret_id
    tfe_tls_privkey_keyvault_secret_id         = var.tfe_tls_privkey_keyvault_secret_id
    tfe_tls_ca_bundle_keyvault_secret_id       = var.tfe_tls_ca_bundle_keyvault_secret_id
    tfe_encryption_password_keyvault_secret_id = var.tfe_encryption_password_keyvault_secret_id
    tfe_image_repository_url                   = var.tfe_image_repository_url
    tfe_image_repository_username              = var.tfe_image_repository_username
    tfe_image_repository_password              = var.tfe_image_repository_password == null ? "" : var.tfe_image_repository_password
    tfe_image_name                             = var.tfe_image_name
    tfe_image_tag                              = var.tfe_image_tag
    container_runtime                          = var.container_runtime
    docker_version                             = var.docker_version
    is_govcloud_region                         = var.is_govcloud_region

    # https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/configuration
    # TFE application settings
    tfe_hostname                  = var.tfe_fqdn
    tfe_operational_mode          = var.tfe_operational_mode
    tfe_capacity_concurrency      = var.tfe_capacity_concurrency
    tfe_capacity_cpu              = var.tfe_capacity_cpu
    tfe_capacity_memory           = var.tfe_capacity_memory
    tfe_license_reporting_opt_out = var.tfe_license_reporting_opt_out
    tfe_run_pipeline_driver       = "docker"
    tfe_run_pipeline_image        = var.tfe_run_pipeline_image == null ? "" : var.tfe_run_pipeline_image
    tfe_backup_restore_token      = ""
    tfe_node_id                   = ""
    tfe_http_port                 = 80
    tfe_https_port                = 443

    # Database settings
    tfe_database_host       = "${azurerm_postgresql_flexible_server.tfe.fqdn}:5432"
    tfe_database_name       = var.tfe_database_name
    tfe_database_user       = azurerm_postgresql_flexible_server.tfe.administrator_login
    tfe_database_password   = azurerm_postgresql_flexible_server.tfe.administrator_password
    tfe_database_parameters = var.tfe_database_paramaters

    # Object storage settings
    tfe_object_storage_type               = "azure"
    tfe_object_storage_azure_account_key  = !var.tfe_object_storage_azure_use_msi ? local.tfe_object_storage_azure_account_key : ""
    tfe_object_storage_azure_account_name = var.is_secondary_region ? data.azurerm_storage_account.tfe[0].name : azurerm_storage_account.tfe[0].name
    tfe_object_storage_azure_container    = var.is_secondary_region ? data.azurerm_storage_container.tfe[0].name : azurerm_storage_container.tfe[0].name
    tfe_object_storage_azure_endpoint     = var.is_govcloud_region ? split(".blob.", azurerm_storage_account.tfe[0].primary_blob_host)[1] : ""
    tfe_object_storage_azure_use_msi      = var.tfe_object_storage_azure_use_msi
    tfe_object_storage_azure_client_id    = var.tfe_object_storage_azure_use_msi ? azurerm_user_assigned_identity.tfe.client_id : ""

    # Redis settings
    tfe_redis_host     = var.tfe_operational_mode == "active-active" ? "${azurerm_redis_cache.tfe[0].hostname}:${local.redis_port}" : ""
    tfe_redis_use_auth = var.tfe_operational_mode == "active-active" ? var.tfe_redis_use_auth : ""
    tfe_redis_use_tls  = var.tfe_operational_mode == "active-active" ? var.tfe_redis_use_tls : ""
    tfe_redis_password = var.tfe_operational_mode == "active-active" && var.tfe_redis_use_auth ? "${azurerm_redis_cache.tfe[0].primary_access_key}" : ""

    # TLS settings
    tfe_tls_cert_file      = "/etc/ssl/private/terraform-enterprise/cert.pem"
    tfe_tls_key_file       = "/etc/ssl/private/terraform-enterprise/key.pem"
    tfe_tls_ca_bundle_file = "/etc/ssl/private/terraform-enterprise/bundle.pem"
    tfe_tls_enforce        = var.tfe_tls_enforce
    tfe_tls_ciphers        = ""
    tfe_tls_version        = ""

    # Observability settings
    tfe_log_forwarding_enabled     = var.tfe_log_forwarding_enabled
    tfe_log_forwarding_config_path = "" # computed inside of tfe_custom_data.sh script
    tfe_metrics_enable             = var.tfe_metrics_enable
    tfe_metrics_http_port          = var.tfe_metrics_http_port
    tfe_metrics_https_port         = var.tfe_metrics_https_port
    fluent_bit_rendered_config     = local.fluent_bit_rendered_config

    # Vault settings
    tfe_vault_use_external  = false
    tfe_vault_disable_mlock = var.tfe_vault_disable_mlock

    # Docker driver settings
    tfe_run_pipeline_docker_extra_hosts = "" # computed inside of tfe_custom_data.sh script if `tfe_hairpin_addressing` is `true`
    tfe_run_pipeline_docker_network     = var.tfe_run_pipeline_docker_network == null ? "" : var.tfe_run_pipeline_docker_network
    tfe_disk_cache_path                 = "/var/cache/tfe-task-worker"
    tfe_disk_cache_volume_name          = "tfe_terraform-enterprise-cache"
    tfe_hairpin_addressing              = var.tfe_hairpin_addressing

    # Network bootstrap settings
    tfe_iact_subnets         = ""
    tfe_iact_time_limit      = 60
    tfe_iact_trusted_proxies = ""
  }
}

#------------------------------------------------------------------------------
# Custom VM image lookup
#------------------------------------------------------------------------------
data "azurerm_image" "custom" {
  count = var.vm_custom_image_name == null ? 0 : 1

  name                = var.vm_custom_image_name
  resource_group_name = var.vm_custom_image_rg_name
}

#------------------------------------------------------------------------------
# Virtual machine scale set (VMSS)
#------------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine_scale_set" "tfe" {
  name                = "${var.friendly_name_prefix}-tfe-vmss"
  resource_group_name = local.resource_group_name
  location            = var.location
  instances           = var.vmss_instance_count
  sku                 = var.vm_sku
  admin_username      = var.vm_admin_username
  overprovision       = false
  upgrade_mode        = "Manual"
  zone_balance        = true
  zones               = var.availability_zones
  health_probe_id     = var.create_lb ? azurerm_lb_probe.tfe[0].id : null
  custom_data         = base64encode(templatefile("${path.module}/templates/tfe_custom_data.sh.tpl", local.custom_data_args))

  scale_in {
    rule = "OldestVM"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.tfe.id]
  }

  dynamic "admin_ssh_key" {
    for_each = var.vm_ssh_public_key != null ? [1] : []

    content {
      username   = var.vm_admin_username
      public_key = var.vm_ssh_public_key
    }
  }

  source_image_id = var.vm_custom_image_name == null ? null : data.azurerm_image.custom[0].id

  dynamic "source_image_reference" {
    for_each = var.vm_custom_image_name == null ? [true] : []

    content {
      publisher = var.vm_image_publisher
      offer     = var.vm_image_offer
      sku       = var.vm_image_sku
      version   = var.vm_image_version
    }
  }

  network_interface {
    name    = "tfe-vm-nic"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = var.vm_subnet_id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.tfe_servers[0].id]
    }
  }

  os_disk {
    caching                = "ReadWrite"
    storage_account_type   = "Premium_LRS"
    disk_size_gb           = 64
    disk_encryption_set_id = var.vm_disk_encryption_set_name != null && var.vm_disk_encryption_set_rg != null ? data.azurerm_disk_encryption_set.vmss[0].id : null
  }

  automatic_instance_repair {
    enabled      = true
    grace_period = "PT15M"
  }

  dynamic "boot_diagnostics" {
    for_each = var.vm_enable_boot_diagnostics ? [1] : []
    content {}
  }

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}-tfe-vmss" },
    var.common_tags
  )
}