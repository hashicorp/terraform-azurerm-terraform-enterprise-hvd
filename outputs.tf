# Copyright IBM Corp. 2024, 2026
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# TFE
#------------------------------------------------------------------------------
output "url" {
  value       = "https://${var.tfe_fqdn}"
  description = "URL of TFE application based on `tfe_fqdn` input."
}

output "tfe_admin_console_url_pattern" {
  value       = !var.tfe_admin_console_disabled ? "https://${var.tfe_fqdn}:${var.tfe_admin_https_port}" : null
  description = "URL pattern to access the TFE Admin Console when it is enabled."
}

output "tfe_explorer_database_warning" {
  value       = var.tfe_explorer_enabled && local.tfe_explorer_uses_primary_database ? "Explorer is enabled and reuses the primary TFE PostgreSQL database. This fallback is intended for non-production use." : null
  description = "Warning emitted when Explorer reuses the primary TFE database."
}

output "secondary_url" {
  value       = var.tfe_hostname_secondary != null ? "https://${var.tfe_hostname_secondary}" : null
  description = "URL of the optional secondary TFE hostname."
}

output "tfe_secondary_public_ip_address" {
  value       = try(azurerm_public_ip.tfe_lb_secondary[0].ip_address, null)
  description = "Public IP address for the managed secondary TFE endpoint when enabled."
}

#------------------------------------------------------------------------------
# Database
#------------------------------------------------------------------------------
output "tfe_database_host" {
  value       = "${azurerm_postgresql_flexible_server.tfe.fqdn}:5432"
  description = "FQDN and port of PostgreSQL Flexible Server."
}

output "tfe_database_name" {
  value       = azurerm_postgresql_flexible_server_database.tfe.name
  description = "Name of PostgreSQL Flexible Server database."
}

#------------------------------------------------------------------------------
# Object storage
#------------------------------------------------------------------------------
output "tfe_object_storage_azure_account_name" {
  value       = try(azurerm_storage_account.tfe[0].name, null)
  description = "Name of primary TFE Azure Storage Account."
}

output "tfe_object_storage_azure_container_name" {
  value       = try(azurerm_storage_container.tfe[0].name, null)
  description = "Name of TFE Azure Storage Container."
}
