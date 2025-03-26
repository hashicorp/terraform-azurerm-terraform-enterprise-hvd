# Deploying TFE in Azure Government Cloud

Normal Azure subscriptions are hosted in what Azure refers to as their _public_ environment (`AzureCloud`). Azure has also defined an environment they call _Azure Government_ (`AzureUSGovernment`). The seperation of these environments means that some internal Azure API endpoints, DNS domains, and more will differ, which impacts some of the configuration setting values for a TFE deployment.

## Configuration settings

This module includes an input variable of type boolean named `is_govcloud_region` that defaults to `false`. Setting this to `true` will change some of the domain names and endpoints to support deploying TFE in the Azure Government cloud environment as follows:

### PostgreSQL

- Changes from `*.postgres.database.azure.com` to `*.postgres.database.usgovcloudapi.net`.

### Blob Storage Account

- Changes from `*.blob.core.windows.net` to `*.blob.core.usgovcloudapi.net`.
- Sets `TFE_OBJECT_STORAGE_AZURE_ENDPOINT` to `blob.core.usgovcloudapi.net`.

### Redis Cache

- Changes from `*.redis.cache.windows.net` to `*.redis.cache.usgovcloudapi.net`

## AzureRM Provider Block

You will need to update the value of `environment` within your azurerm provider block within your root Terraform configuration that deploys this module to `usgovernment` like so:

```hcl
provider "azurerm" {
  environment = "usgovernment"
  features {}
}
```

## AzureRM Remote State Backend Configuration

You will need to ensure that you specify the `environment` key within your AzureRM remote state backend configuration with a value of `usgovernment` like so:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "StorageAccount-ResourceGroup"
    storage_account_name = "abcd1234"
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
    environment          = usgovernment
  }
}
```
## Troubleshooting AzureRM Authentication Issues

First, see this link for instructions on setting Azure CLI to use the US Government Cloud:  
[Azure CLI - Logging into the Azure CLI](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli#logging-into-the-azure-cli)

In some cases, it may be necessary to set the `ARM_ENVIRONMENT` variable to `usgovernment`:

```bash
export ARM_ENVIRONMENT=usgovernment
```