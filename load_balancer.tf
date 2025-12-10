# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# Public IP (optional)
#------------------------------------------------------------------------------
resource "azurerm_public_ip" "tfe_lb" {
  count = var.create_lb && !var.lb_is_internal ? 1 : 0

  name                = "${var.friendly_name_prefix}-tfe-lb-ip"
  resource_group_name = local.resource_group_name
  location            = var.location
  zones               = var.availability_zones
  sku                 = "Standard"
  allocation_method   = "Static"

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}-tfe-lb-ip" },
    var.common_tags
  )
}

#------------------------------------------------------------------------------
# Azure load balancer
#------------------------------------------------------------------------------
locals {
  lb_frontend_name_suffix = var.lb_is_internal ? "internal" : "external"
}

resource "azurerm_lb" "tfe" {
  count = var.create_lb ? 1 : 0

  name                = "${var.friendly_name_prefix}-tfe-lb"
  resource_group_name = local.resource_group_name
  location            = var.location
  sku                 = "Standard"
  sku_tier            = "Regional"

  frontend_ip_configuration {
    name                          = "tfe-frontend-${local.lb_frontend_name_suffix}"
    zones                         = var.lb_is_internal ? var.availability_zones : null
    public_ip_address_id          = !var.lb_is_internal ? azurerm_public_ip.tfe_lb[0].id : null
    subnet_id                     = var.lb_is_internal ? var.lb_subnet_id : null
    private_ip_address_allocation = var.lb_is_internal ? "Static" : null
    private_ip_address            = var.lb_is_internal ? var.lb_private_ip : null
  }

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}-tfe-lb" },
    var.common_tags
  )
}

resource "azurerm_lb_backend_address_pool" "tfe_servers" {
  count = var.create_lb ? 1 : 0

  name            = "${var.friendly_name_prefix}-tfe-backend"
  loadbalancer_id = azurerm_lb.tfe[0].id
}

resource "azurerm_lb_probe" "tfe" {
  count = var.create_lb ? 1 : 0

  name                = "tfe-app-lb-probe"
  loadbalancer_id     = azurerm_lb.tfe[0].id
  protocol            = "Https"
  port                = 443
  request_path        = "/_health_check"
  interval_in_seconds = 15
  number_of_probes    = 5
}

resource "azurerm_lb_rule" "tfe" {
  count = var.create_lb ? 1 : 0

  name                           = "${var.friendly_name_prefix}-tfe-lb-rule-app"
  loadbalancer_id                = azurerm_lb.tfe[0].id
  probe_id                       = azurerm_lb_probe.tfe[0].id
  protocol                       = "Tcp"
  frontend_ip_configuration_name = azurerm_lb.tfe[0].frontend_ip_configuration[0].name
  frontend_port                  = 443
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.tfe_servers[0].id]
  backend_port                   = 443
}