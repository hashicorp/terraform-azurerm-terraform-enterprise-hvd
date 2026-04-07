# Plan: Terraform Enterprise Explorer support

## Implementation approach

1. Add Explorer variables for enablement, host, name, user, parameters, and Key Vault secret reference for the password.
2. Compute effective Explorer database settings in `compute.tf`, defaulting to the primary TFE database when dedicated settings are omitted.
3. Extend the startup template to export Explorer settings for both Docker and Podman manifests.
4. Add outputs, example wiring, and documentation for dedicated and fallback modes.

## Azure-specific notes

- Reuse the existing Key Vault secret and PostgreSQL patterns instead of AWS IAM or Secrets Manager features.
- Keep the initial Azure port to password-based Explorer database access unless a product-supported Azure passwordless mode is confirmed.
