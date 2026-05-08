# Changelog

All notable changes to this module will be documented in this file.

## [1.0.1] - 2026-05-08

### Fixed

- Changed `azurerm_public_ip` allocation method from `Dynamic` to `Static` and SKU from `Basic` to `Standard`. Dynamic public IPs are only assigned when the VM boots, so Terraform reads an empty `ip_address` attribute during apply (before the VM starts), making outputs such as `ssh_commands` unusable. Static allocation reserves the address at resource creation time, ensuring it is readable immediately after `terraform apply`.
- Updated `ssh_commands` output to include `-i <path/to/private/key>` as a literal placeholder. The path is intentionally not sourced from a variable to avoid it appearing in Terraform state, plan output, and logs. Following the KISS principle (Keep It Simple, Stupid) — adding a variable would introduce complexity (an extra input, conditional logic, sensitive-flag considerations) to solve a problem the user can trivially solve themselves by replacing the placeholder before running the command. The simplest design that works is the right design.

## [1.0.0] - 2026-05-08

### Added

- Initial release of the `terraform-azurerm-compute` module.
