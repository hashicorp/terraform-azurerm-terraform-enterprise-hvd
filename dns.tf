#------------------------------------------------------------------------------
# DNS zone lookup
#------------------------------------------------------------------------------
data "azurerm_dns_zone" "tfe" {
  count = var.create_tfe_public_dns_record && var.public_dns_zone_name != null ? 1 : 0

  name                = var.public_dns_zone_name
  resource_group_name = var.public_dns_zone_rg_name
}

data "azurerm_private_dns_zone" "tfe" {
  count = var.create_tfe_private_dns_record && var.private_dns_zone_name != null ? 1 : 0

  name                = var.private_dns_zone_name
  resource_group_name = var.private_dns_zone_rg_name
}

#------------------------------------------------------------------------------
# DNS A record
#------------------------------------------------------------------------------
locals {
  tfe_hostname_public  = var.create_tfe_public_dns_record && var.public_dns_zone_name != null ? trimsuffix(substr(var.tfe_fqdn, 0, length(var.tfe_fqdn) - length(var.public_dns_zone_name) - 1), ".") : var.tfe_fqdn
  tfe_hostname_private = var.create_tfe_private_dns_record && var.private_dns_zone_name != null ? trim(split(var.private_dns_zone_name, var.tfe_fqdn)[0], ".") : var.tfe_fqdn
}

resource "azurerm_dns_a_record" "tfe" {
  count = var.create_tfe_public_dns_record && var.public_dns_zone_name != null && var.create_lb ? 1 : 0

  name                = local.tfe_hostname_public
  resource_group_name = var.public_dns_zone_rg_name
  zone_name           = data.azurerm_dns_zone.tfe[0].name
  ttl                 = 300
  records             = var.lb_is_internal ? [azurerm_lb.tfe[0].private_ip_address] : null
  target_resource_id  = !var.lb_is_internal ? azurerm_public_ip.tfe_lb[0].id : null
  tags                = var.common_tags
}

resource "azurerm_private_dns_a_record" "tfe" {
  count = var.create_tfe_private_dns_record && var.private_dns_zone_name != null ? 1 : 0

  name                = local.tfe_hostname_private
  resource_group_name = var.private_dns_zone_rg_name
  zone_name           = data.azurerm_private_dns_zone.tfe[0].name
  ttl                 = 300
  records             = var.lb_is_internal ? [azurerm_lb.tfe[0].private_ip_address] : null
  tags                = var.common_tags
}

// Moved to prereqs where DNS zone creation occurs
# resource "azurerm_private_dns_zone_virtual_network_link" "tfe" {
#   count = var.create_tfe_private_dns_record && var.private_dns_zone_name != null ? 1 : 0

#   name                  = "${var.friendly_name_prefix}-tfe-priv-dns-zone-vnet-link"
#   resource_group_name   = var.private_dns_zone_rg_name
#   private_dns_zone_name = data.azurerm_private_dns_zone.tfe[0].name
#   virtual_network_id    = var.vnet_id
#   tags                  = var.common_tags
# }