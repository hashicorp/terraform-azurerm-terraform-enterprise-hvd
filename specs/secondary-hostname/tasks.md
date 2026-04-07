# Tasks: Secondary hostname support

1. Add secondary-hostname and TLS inputs in `variables.tf` and `compute.tf`.
2. Update `templates/tfe_custom_data.sh.tpl`, `load_balancer.tf`, `dns.tf`, and `outputs.tf`.
3. Update `examples/main/*`, `README.md`, and docs.
4. Run `task test` and `task terraform-docs`.
