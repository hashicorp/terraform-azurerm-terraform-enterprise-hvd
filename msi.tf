# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# AzureRM client config
#------------------------------------------------------------------------------
data "azurerm_client_config" "current" {}

#------------------------------------------------------------------------------
# TFE user-assigned identity
#------------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "tfe" {
  name                = "${var.friendly_name_prefix}-tfe-msi"
  resource_group_name = local.resource_group_name
  location            = var.location
}

data "azurerm_key_vault" "bootstrap" {
  name                = var.bootstrap_keyvault_name
  resource_group_name = var.bootstrap_keyvault_rg_name
}

resource "azurerm_role_assignment" "tfe_kv_reader" {
  scope                = data.azurerm_key_vault.bootstrap.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.tfe.principal_id
}

resource "azurerm_key_vault_access_policy" "tfe_kv_reader" {
  key_vault_id = data.azurerm_key_vault.bootstrap.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.tfe.principal_id

  secret_permissions = [
    "Get",
  ]
}

resource "azurerm_role_assignment" "tfe_sa_owner" {
  count = var.tfe_object_storage_azure_use_msi ? 1 : 0

  scope                = azurerm_storage_account.tfe[0].id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.tfe.principal_id
}

#------------------------------------------------------------------------------
# PostgreSQL flexible server user-assigned identity
#------------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "postgres" {
  count = var.postgres_cmk_keyvault_key_id != null ? 1 : 0

  name                = "${var.friendly_name_prefix}-tfe-postgres-msi"
  resource_group_name = local.resource_group_name
  location            = var.location
}

resource "azurerm_key_vault_access_policy" "postgres_cmk" {
  count = var.postgres_cmk_keyvault_key_id != null && var.postgres_cmk_keyvault_id != null ? 1 : 0

  key_vault_id = var.postgres_cmk_keyvault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.postgres[0].principal_id

  key_permissions = [
    "Get",
    "WrapKey",
    "UnwrapKey",
  ]
}

#------------------------------------------------------------------------------
# Storage account user-assigned identity
#------------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "storage_account" {
  count = var.storage_account_cmk_keyvault_key_id != null ? 1 : 0

  name                = "${var.friendly_name_prefix}-tfe-blob-msi"
  resource_group_name = local.resource_group_name
  location            = var.location
}

resource "azurerm_key_vault_access_policy" "storage_account_cmk" {
  count = var.storage_account_cmk_keyvault_key_id != null && var.storage_account_cmk_keyvault_id != null ? 1 : 0

  key_vault_id = var.storage_account_cmk_keyvault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.storage_account[0].principal_id

  key_permissions = [
    "Get",
    "WrapKey",
    "UnwrapKey",
  ]
}

#------------------------------------------------------------------------------
# Virtual machine scale set (VMSS) disk encryption set
#------------------------------------------------------------------------------
data "azurerm_disk_encryption_set" "vmss" {
  count = var.vm_disk_encryption_set_name != null && var.vm_disk_encryption_set_rg != null ? 1 : 0

  name                = var.vm_disk_encryption_set_name
  resource_group_name = var.vm_disk_encryption_set_rg
}

resource "azurerm_role_assignment" "tfe_vmss_disk_encryption_set_reader" {
  count = var.vm_disk_encryption_set_name != null && var.vm_disk_encryption_set_rg != null ? 1 : 0

  scope                = data.azurerm_disk_encryption_set.vmss[0].id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.tfe.principal_id
}


