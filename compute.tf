# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

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
  is_calver_tfe_image_tag  = can(regex("^v[0-9]{6}-[0-9]+$", var.tfe_image_tag))
  normalized_tfe_image_tag = trimprefix(var.tfe_image_tag, "v")
  is_semver_tfe_image_tag  = can(regex("^[0-9]+\\.[0-9]+(\\.[0-9]+)?$", local.normalized_tfe_image_tag))
  tfe_image_tag_parts      = local.is_semver_tfe_image_tag ? split(".", local.normalized_tfe_image_tag) : []
  tfe_image_tag_major      = local.is_semver_tfe_image_tag ? tonumber(local.tfe_image_tag_parts[0]) : 0
  tfe_image_tag_minor      = local.is_semver_tfe_image_tag ? tonumber(local.tfe_image_tag_parts[1]) : 0
  tfe_image_tag_patch      = local.is_semver_tfe_image_tag && length(local.tfe_image_tag_parts) > 2 ? tonumber(local.tfe_image_tag_parts[2]) : 0
  tfe_redis_uses_managed_redis = (
    !local.is_calver_tfe_image_tag &&
    local.is_semver_tfe_image_tag &&
    (
      local.tfe_image_tag_major > 1 ||
      (
        local.tfe_image_tag_major == 1 &&
        (
          local.tfe_image_tag_minor > 0 ||
          (local.tfe_image_tag_minor == 0 && local.tfe_image_tag_patch >= 1)
        )
      )
    )
  )
  tfe_readiness_uses_api = (
    !local.is_calver_tfe_image_tag &&
    (
      !local.is_semver_tfe_image_tag ||
      local.tfe_image_tag_major > 1 ||
      (
        local.tfe_image_tag_major == 1 &&
        (
          local.tfe_image_tag_minor > 2 ||
          (local.tfe_image_tag_minor == 2 && local.tfe_image_tag_patch >= 1)
        )
      )
    )
  )
  tfe_health_check_path       = local.tfe_readiness_uses_api ? "/api/v1/health/readiness" : "/_health_check"
  tfe_startup_script_tpl      = var.custom_tfe_startup_script_template != null ? "${path.cwd}/templates/${var.custom_tfe_startup_script_template}" : "${path.module}/templates/tfe_custom_data.sh.tpl"
  redis_private_dns_zone_name = local.tfe_redis_uses_managed_redis ? "privatelink.redis.azure.net" : (var.is_govcloud_region ? "privatelink.redis.cache.usgovcloudapi.net" : "privatelink.redis.cache.windows.net")
  redis_legacy_port           = var.tfe_redis_use_tls ? 6380 : 6379
  redis_managed_port          = var.tfe_redis_use_tls ? 10000 : 10001
  redis_private_endpoint_targets = var.tfe_operational_mode == "active-active" ? (
    local.tfe_redis_uses_managed_redis ? {
      main = {
        resource_id      = azurerm_managed_redis.tfe[0].id
        dns_record_name  = join(".", slice(split(".", azurerm_managed_redis.tfe[0].hostname), 0, length(split(".", azurerm_managed_redis.tfe[0].hostname)) - 3))
        subresource_name = "redisEnterprise"
      }
      sidekiq = {
        resource_id      = azurerm_managed_redis.tfe_sidekiq[0].id
        dns_record_name  = join(".", slice(split(".", azurerm_managed_redis.tfe_sidekiq[0].hostname), 0, length(split(".", azurerm_managed_redis.tfe_sidekiq[0].hostname)) - 3))
        subresource_name = "redisEnterprise"
      }
      } : {
      main = {
        resource_id      = azurerm_redis_cache.tfe[0].id
        dns_record_name  = azurerm_redis_cache.tfe[0].name
        subresource_name = "redisCache"
      }
    }
  ) : {}
  redis_main_hostname = var.tfe_operational_mode == "active-active" ? (
    local.tfe_redis_uses_managed_redis ? azurerm_managed_redis.tfe[0].hostname : azurerm_redis_cache.tfe[0].hostname
  ) : ""
  redis_sidekiq_hostname = var.tfe_operational_mode == "active-active" && local.tfe_redis_uses_managed_redis ? azurerm_managed_redis.tfe_sidekiq[0].hostname : ""
  tfe_object_storage_azure_account_key = var.is_secondary_region ? data.azurerm_storage_account.tfe[0].primary_access_key : azurerm_storage_account.tfe[0].primary_access_key

  custom_data_args = {
    # Bootstrap
    tfe_license_keyvault_secret_id             = var.tfe_license_keyvault_secret_id
    tfe_tls_cert_keyvault_secret_id            = var.tfe_tls_cert_keyvault_secret_id
    tfe_tls_privkey_keyvault_secret_id         = var.tfe_tls_privkey_keyvault_secret_id
    tfe_tls_ca_bundle_keyvault_secret_id       = var.tfe_tls_ca_bundle_keyvault_secret_id
    tfe_encryption_password_keyvault_secret_id = var.tfe_encryption_password_keyvault_secret_id
    tfe_bootstrap_azure_client_id              = azurerm_user_assigned_identity.tfe.client_id
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
    tfe_http_port                 = var.tfe_http_port
    tfe_https_port                = var.tfe_https_port
    tfe_admin_https_port          = var.tfe_admin_https_port
    tfe_admin_console_disabled    = var.tfe_admin_console_disabled
    tfe_health_check_path         = local.tfe_health_check_path

    # Database settings
    tfe_database_host       = "${azurerm_postgresql_flexible_server.tfe.fqdn}:5432"
    tfe_database_name       = var.tfe_database_name
    tfe_database_user       = azurerm_postgresql_flexible_server.tfe.administrator_login
    tfe_database_password   = data.azurerm_key_vault_secret.tfe_database_password.value
    tfe_database_parameters = var.tfe_database_parameters


    # Object storage settings
    tfe_object_storage_type               = "azure"
    tfe_object_storage_azure_account_key  = !var.tfe_object_storage_azure_use_msi ? local.tfe_object_storage_azure_account_key : ""
    tfe_object_storage_azure_account_name = var.is_secondary_region ? data.azurerm_storage_account.tfe[0].name : azurerm_storage_account.tfe[0].name
    tfe_object_storage_azure_container    = var.is_secondary_region ? data.azurerm_storage_container.tfe[0].name : azurerm_storage_container.tfe[0].name
    tfe_object_storage_azure_endpoint     = var.is_govcloud_region ? "blob.core.usgovcloudapi.net" : ""
    tfe_object_storage_azure_use_msi      = var.tfe_object_storage_azure_use_msi
    tfe_object_storage_azure_client_id    = var.tfe_object_storage_azure_use_msi ? azurerm_user_assigned_identity.tfe.client_id : ""

    # Redis settings
    tfe_redis_host = var.tfe_operational_mode == "active-active" ? (
      local.tfe_redis_uses_managed_redis ? "${local.redis_main_hostname}:${local.redis_managed_port}" : "${local.redis_main_hostname}:${local.redis_legacy_port}"
    ) : ""
    tfe_redis_use_auth = var.tfe_operational_mode == "active-active" ? var.tfe_redis_use_auth : ""
    tfe_redis_use_tls  = var.tfe_operational_mode == "active-active" ? var.tfe_redis_use_tls : ""
    tfe_redis_password = var.tfe_operational_mode == "active-active" && var.tfe_redis_use_auth ? (
      local.tfe_redis_uses_managed_redis ? try(azurerm_managed_redis.tfe[0].default_database[0].primary_access_key != null ? azurerm_managed_redis.tfe[0].default_database[0].primary_access_key : "", "") : azurerm_redis_cache.tfe[0].primary_access_key
    ) : ""
    tfe_redis_requires_sidekiq_endpoint = var.tfe_operational_mode == "active-active" && local.tfe_redis_uses_managed_redis
    tfe_redis_sidekiq_host              = var.tfe_operational_mode == "active-active" && local.tfe_redis_uses_managed_redis ? "${local.redis_sidekiq_hostname}:${local.redis_managed_port}" : ""
    tfe_redis_sidekiq_use_auth          = var.tfe_operational_mode == "active-active" && local.tfe_redis_uses_managed_redis ? var.tfe_redis_use_auth : ""
    tfe_redis_sidekiq_use_tls           = var.tfe_operational_mode == "active-active" && local.tfe_redis_uses_managed_redis ? var.tfe_redis_use_tls : ""
    tfe_redis_sidekiq_password          = var.tfe_operational_mode == "active-active" && local.tfe_redis_uses_managed_redis && var.tfe_redis_use_auth ? try(azurerm_managed_redis.tfe_sidekiq[0].default_database[0].primary_access_key != null ? azurerm_managed_redis.tfe_sidekiq[0].default_database[0].primary_access_key : "", "") : ""

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

locals {
  os_image_map = {
    redhat8    = { publisher = "RedHat", offer = "RHEL" }
    redhat9    = { publisher = "RedHat", offer = "RHEL" }
    ubuntu2204 = { publisher = "Canonical", offer = "0001-com-ubuntu-server-jammy" }
    ubuntu2404 = { publisher = "Canonical", offer = "ubuntu-24_04-lts" }
  }

  vm_image_publisher = local.os_image_map[var.vm_os_image].publisher
  vm_image_offer     = local.os_image_map[var.vm_os_image].offer
  vm_image_sku = (
    var.vm_os_image == "redhat8" ? "810-gen2" :
    var.vm_os_image == "redhat9" ? "95_gen2" :
    var.vm_os_image == "ubuntu2204" ? "22_04-lts-gen2" :
    var.vm_os_image == "ubuntu2404" ? "ubuntu-pro" : null
  )
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
# Latest OS image lookup
#------------------------------------------------------------------------------
data "azurerm_platform_image" "latest_os_image" {
  location  = var.location
  publisher = local.vm_image_publisher
  offer     = local.vm_image_offer
  sku       = local.vm_image_sku
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
  # custom_data         = base64encode(templatefile("${path.module}/templates/tfe_custom_data.sh.tpl", local.custom_data_args))
  custom_data = base64encode(templatefile("${local.tfe_startup_script_tpl}", local.custom_data_args))

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

  source_image_id = var.vm_custom_image_name != null ? data.azurerm_image.custom[0].id : null

  dynamic "source_image_reference" {
    for_each = var.vm_custom_image_name == null ? [true] : []

    content {
      publisher = local.vm_image_publisher
      offer     = local.vm_image_offer
      sku       = local.vm_image_sku
      version   = data.azurerm_platform_image.latest_os_image.version
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
