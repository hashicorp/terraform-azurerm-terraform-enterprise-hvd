# Plan: Secondary hostname support

## Implementation approach

1. Add inputs for the secondary hostname, hostname-choice settings, and secondary TLS Key Vault secrets.
2. Extend `compute.tf` and `templates/tfe_custom_data.sh.tpl` to retrieve secondary TLS files and configure the TFE runtime.
3. Add optional Azure public-IP/load-balancer/DNS support for a managed secondary hostname path.
4. Update examples, outputs, and docs.

## Azure-specific notes

- The cleanest Azure shape is to reuse the existing Standard Load Balancer with an additional public frontend and rule rather than creating an entirely separate load balancer.
- DNS should stay optional so callers can bring their own external hostname path.
