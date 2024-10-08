# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
  }
}

provider "azurerm" {
  features {}
}

module "tfe" {
  source = "../.."

  # --- Common --- #
  create_resource_group = var.create_resource_group
  resource_group_name   = var.resource_group_name
  location              = var.location
  friendly_name_prefix  = var.friendly_name_prefix
  common_tags           = var.common_tags

  # --- Bootstrap --- #
  bootstrap_keyvault_name                    = var.bootstrap_keyvault_name
  bootstrap_keyvault_rg_name                 = var.bootstrap_keyvault_rg_name
  tfe_license_keyvault_secret_id             = var.tfe_license_keyvault_secret_id
  tfe_tls_cert_keyvault_secret_id            = var.tfe_tls_cert_keyvault_secret_id
  tfe_tls_privkey_keyvault_secret_id         = var.tfe_tls_privkey_keyvault_secret_id
  tfe_tls_ca_bundle_keyvault_secret_id       = var.tfe_tls_ca_bundle_keyvault_secret_id
  tfe_encryption_password_keyvault_secret_id = var.tfe_encryption_password_keyvault_secret_id

  # --- TFE config settings --- #
  tfe_fqdn      = var.tfe_fqdn
  tfe_image_tag = var.tfe_image_tag

  # --- Networking --- #
  vnet_id         = var.vnet_id
  lb_subnet_id    = var.lb_subnet_id
  lb_is_internal  = var.lb_is_internal
  lb_private_ip   = var.lb_private_ip
  vm_subnet_id    = var.vm_subnet_id
  db_subnet_id    = var.db_subnet_id
  redis_subnet_id = var.redis_subnet_id

  # --- DNS (optional) --- #
  create_tfe_private_dns_record = var.create_tfe_private_dns_record
  private_dns_zone_name         = var.private_dns_zone_name
  private_dns_zone_rg_name      = var.private_dns_zone_rg_name

  # --- Compute --- #
  vmss_instance_count = var.vmss_instance_count
  vm_ssh_public_key   = var.vm_ssh_public_key
  vm_image_publisher  = var.vm_image_publisher
  vm_image_offer      = var.vm_image_offer
  vm_image_sku        = var.vm_image_sku
  vm_sku              = var.vm_sku
  container_runtime   = var.container_runtime

  # --- Database --- #
  tfe_database_password_keyvault_secret_name = var.tfe_database_password_keyvault_secret_name
  postgres_enable_high_availability          = var.postgres_enable_high_availability
  postgres_geo_redundant_backup_enabled      = var.postgres_geo_redundant_backup_enabled

  # --- Object storage --- #
  storage_account_ip_allow = var.storage_account_ip_allow

  # --- Log forwarding (optional) --- #
  tfe_log_forwarding_enabled      = var.tfe_log_forwarding_enabled
  log_fwd_destination_type        = var.log_fwd_destination_type
  log_analytics_workspace_name    = var.log_analytics_workspace_name
  log_analytics_workspace_rg_name = var.log_analytics_workspace_rg_name
}