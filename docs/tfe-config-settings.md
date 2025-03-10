# TFE configuration settings

In order to bootstrap and automate the deployment of TFE, the [tfe_custom_data.sh](https://github.com/hashicorp/terraform-azurerm-terraform-enterprise-hvd/blob/0.2.0/templates/tfe_custom_data.sh.tpl) dynamically generates a `docker-compose.yaml` containing all of the TFE configuration settings before ultimately bringing up the application. Some of these settings values are derived from input variables, some are interpolated directly from other infrastructure resources that are created by the module, and some are computed for you.

Because we have bootstrapped and automated the TFE deployment, and our TFE application data is decoupled from the VM(s), the VMs are stateless, ephemeral, and are treated as _immutable_. Therefore, the process of updating or modifying a TFE configuration setting involves replacing/re-imaing the VMs within the TFE virtual machine scale set (VMSS), rather than modifying the running VMs in-place. In other words, an settings change effectively means a re-install of TFE.

## Configuration settings reference

The [Terraform Enterprise Flexible Deployment Options configuration reference](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/configuration) page contains all of the available settings, their descriptions, and their default values. If you would like to configure one of these settings for your TFE deployment with a non-default value, then look to see if the setting is defined in the [variables.tf](https://github.com/hashicorp/terraform-azurerm-terraform-enterprise-hvd/blob/0.2.0/variables.tf) of this module. If so, you can set the variable and desired value within your own root Terraform configuration that deploys this module, and subsequently run Terraform to update (re-image/replace) the VMs within your TFE VMSS.

## Where to look in the code

Within the [compute.tf](https://github.com/hashicorp/terraform-azurerm-terraform-enterprise-hvd/blob/0.2.0/compute.tf) file, you will see a `locals` block with a map inside of it called `custom_data_args`. Almost all of the TFE configuration settings are passed from here into the [tfe_custom_data.sh](https://github.com/hashicorp/terraform-azurerm-terraform-enterprise-hvd/blob/0.2.0/templates/tfe_custom_data.sh.tpl) script.

Within the [tfe_custom_data.sh](https://github.com/hashicorp/terraform-azurerm-terraform-enterprise-hvd/blob/0.2.0/templates/tfe_custom_data.sh.tpl) script there is a function named `generate_tfe_docker_compose` that is responsible for receiving all of those inputs and dynamically generating the `docker-compose.yaml` file. After a successful install process, this can be found on your TFE VM(s) within `/etc/tfe/docker-compose.yaml`.
