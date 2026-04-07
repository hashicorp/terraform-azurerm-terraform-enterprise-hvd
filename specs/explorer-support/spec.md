# Spec: Terraform Enterprise Explorer support

## Summary

Port Terraform Enterprise Explorer configuration support into the Azure TFE VM module using Azure-native database and secret patterns.

## Requirements

1. The module must support enabling Explorer independently of the core TFE deployment.
2. The module must support Explorer using either dedicated database settings or a fallback to the primary TFE database for non-production use.
3. Explorer database credentials must follow the module's Azure Key Vault pattern.
4. The module must emit a warning output when Explorer is enabled but reuses the primary TFE database.
5. Docs and examples must explain the Azure-specific Explorer database configuration.

## Acceptance criteria

- New Explorer variables are exposed in `variables.tf` and `examples/main/variables.tf`.
- `compute.tf` computes effective Explorer DB settings and passes them into the startup template.
- Docker and Podman runtime config include `TFE_EXPLORER_DATABASE_*` env vars when Explorer is enabled.
- `outputs.tf` includes a warning output for shared-database fallback.
- The module validates from the root and `examples/main`.
