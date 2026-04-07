# Spec: Readiness API and admin console support

## Summary

Port the upstream readiness-endpoint handling and admin-console support into the Azure TFE VM module.

## Requirements

1. The module must select the correct TFE health-check path from `tfe_image_tag` so Azure load balancer probes and bootstrap polling use the same endpoint.
2. The module must support the TFE admin console behind the Azure load balancer on a configurable admin HTTPS port.
3. The admin console must default to disabled and require explicit CIDR allowlists when enabled.
4. The module must expose an output showing the admin console URL pattern when enabled.
5. Examples and docs must explain the new readiness logic and the network prerequisites for the admin console.

## Acceptance criteria

- `load_balancer.tf` no longer hardcodes `/_health_check`.
- `templates/tfe_custom_data.sh.tpl` uses the same effective readiness path as Terraform.
- New inputs exist for `tfe_admin_https_port`, `tfe_admin_console_disabled`, and `cidr_allow_ingress_tfe_admin_console`.
- The generated Docker/Podman runtime config includes `TFE_ADMIN_HTTPS_PORT` and conditionally `TFE_ADMIN_CONSOLE_DISABLED`.
- The module validates from the root and `examples/main`.
