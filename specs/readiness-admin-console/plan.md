# Plan: Readiness API and admin console support

## Implementation approach

1. Add Terraform locals to compute the health-check path from `tfe_image_tag`.
2. Thread the derived path through the Azure LB probe and startup template.
3. Add admin-console inputs, load balancer rule, output, and runtime environment wiring.
4. Mirror the new inputs through `examples/main` and document the required Azure NSG behavior.

## Azure-specific notes

- Azure VMSS health depends on the LB probe, so readiness path changes must be exact.
- The module does not manage NSGs; admin-console CIDR inputs are configuration contract and documentation for prereqs/out-of-band firewall policy.
- The existing LB can expose both the app and admin-console ports without introducing a second Azure load balancer.
