# TFE version upgrades

TFE follows a monthly release cadence. See the [Terraform Enterprise Releases](https://developer.hashicorp.com/terraform/enterprise/releases) page for full details on the releases. Because we have bootstrapped and automated the TFE deployment, and our TFE application data is decoupled from the VM(s), the VMs are stateless, ephemeral, and are treated as _immutable_. Therefore, the process of upgrading to a new TFE version involves replacing/re-imaing the VMs within the TFE virtual machine scale set (VMSS), rather than modifying the running VMs in-place. In other words, an upgrade effectively is a re-install of TFE.

This module includes an input variable named `tfe_image_tag` that dicates which version of TFE is deployed.

## Procedure

1. Determine your desired version of TFE from the [Terraform Enterprise Releases](https://developer.hashicorp.com/terraform/enterprise/releases) page. The value that you need will be in the **Version** column of the table that is displayed. Ensure you are on the correct tab of the table based on the container runtime you have chosen for your deployment (Docker or Podman). When determing your target TFE version to upgrade to, be sure to check if there are any required releases to upgrade to first in between your current and target version (denoted by a `*` character in the table).

1. During a maintenance window, connect to one of your existing TFE VMs and gracefully drain the node(s) from being able to execute any new Terraform runs.

    Access the TFE command line (`tfectl`) with Docker:

    ```sh
    sudo docker exec -it <tfe-container-name> bash
    ```

    Access the TFE command line (`tfectl`) with Podman:

    ```sh
    sudo podman exec -it <tfe-container-name> bash
    ```

    Gracefully stop work on all nodes:

    ```sh
    tfectl node drain --all
    ```

    For more details on the above commands, see the following documentation:
    - [Access the TFE Command Line](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/admin/admin-cli/cli-access)
    - [Gracefully Stop Work on a Node](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/admin/admin-cli/admin-cli#gracefully-stop-work-on-a-node)

1. Generate a backup of your Azure PostgreSQL flexible server TFE database.

1. Update the value of the `tfe_image_tag` input variable within your `terraform.tfvars` file.

    ```hcl
    tfe_image_tag = "v202407-1"
    ```

1. From within the directory managing your TFE deployment, run `terraform apply` to update (re-image) the TFE VM(s) within your TFE VMSS.

1. This process will effectively re-install TFE to the target version on the existing TFE VM(s) within your TFE VMSS. Ensure that the VM(s) have been updated (re-imaged) with the new changes. You can monitor the `tfe_custom_data` (cloud-init) script to ensure a successful re-install (see step 7 in the [Usage](https://github.com/hashicorp/terraform-azurerm-terraform-enterprise-hvd/blob/0.2.0/README.md#usage) section of the main README).
