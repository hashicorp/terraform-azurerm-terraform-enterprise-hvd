# Main Example

This directory contains a ready-made Terraform configuration and an [example terraform.tfvars file](./terraform.tfvars.example) for deploying this module.
Refer to the **Architectural decisions** section below for details on some of the key settings and their corresponding input variables to deploy your TFE instance.

## Architectural decisions

### Operational mode

**Input variable:** `tfe_operational_mode`

Supported values:
 - `active-active` (recommended)
 - `external`

### Operating system

**Input variable:** `vm_os_image`

Supported values:
- `rhel9` & `rhel8` - will set your container runtime to `podman`
- `ubuntu2404` & `ubuntu2204` - will set your container runtime to `docker`
- default is `rhel9`

### Container runtime

**Input variable:** `container_runtime`

Supported values:
 - `docker` - required `vm_os_image` is `ubuntu*`
 - `podman` - required `vm_os_image` is `rhel*`

### Load balancing

#### Load balancer scheme (exposure)

**Input variable:** `lb_is_internal` (bool)

Supported values:
- `true` - deploy an _internal_ load balancer; `lb_subnet_ids` must be _private_ subnets
- `false` - deploy an _Internet-facing_ load balancer; `lb_subnet_ids` must be _public_ subnets

We recommend deploying an internal load balancer unless you have a specific use case where your TFE users/clients or VCS need to be able to reach your TFE instance from the Internet.

### Log forwarding

**Input variable:** `tfe_log_forwarding_enabled` (bool)

Supported values:
- `true` - enabled log forwarding for TFE
- `false` - disables log forwarding for TFE

**Input variable:** `log_fwd_destination_type`

Supported values:
- `log_analytics` - sets a Log Analytics workspace; `log_analytics_workspace_name` is also required
- `custom` - sets a custom logging destination; specify your own custom FluentBit config via `custom_fluent_bit_config`