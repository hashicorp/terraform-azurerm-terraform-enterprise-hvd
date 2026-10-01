# Spec: Secondary hostname support

## Summary

Port secondary hostname support into the Azure TFE VM module so external integrations can use a managed or caller-managed secondary hostname path.

## Requirements

1. The module must support configuring `TFE_HOSTNAME_SECONDARY` and the hostname-choice settings for OIDC, VCS, and run tasks.
2. The module must support separate secondary TLS materials from Azure Key Vault.
3. The module must support an optional managed Azure public endpoint and public DNS record for the secondary hostname.
4. The module must preserve the existing primary hostname path and keep secondary support optional.
5. Docs and examples must explain the managed and caller-managed secondary-hostname modes.

## Acceptance criteria

- New secondary-hostname and secondary-TLS variables are added to module and example inputs.
- The startup template writes the secondary hostname and TLS env vars when configured.
- Azure networking resources support an optional secondary public entry point.
- Outputs and docs describe the secondary URL and DNS/TLS prerequisites.
- The module validates from the root and `examples/main`.
