#------------------------------------------------------------------------------
# TFE
#------------------------------------------------------------------------------
output "url" {
  value       = "https://${var.tfe_fqdn}"
  description = "URL of TFE application based on `tfe_fqdn` input."
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

