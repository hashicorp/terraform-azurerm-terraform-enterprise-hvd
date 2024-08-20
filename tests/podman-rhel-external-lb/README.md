# CI Test - Podman | RHEL | External Load Balancer

PLACEHOLDER - coming soon.

This directory contains the Terraform configuration used in the `podman-rhel-external-lb` test case for this Terraform module. The specifications are as follows:

| Parameter                   | Value                        |
|-----------------------------|------------------------------|
| Operational Mode            | `active-active`              |
| Container Runtime           | `podman`                     |
| Operating System            | `RHEL 9`                     |
| Load Balancer Type          | `Azure Load Balancer`        |
| Load Balancer Scheme        | `external` (Internet-facing) |
| Log Forwarding Destination  | `log_analytics`              |