// vm_ids is keyed by VM name. All other outputs are keyed by "<vm-name>-<nic-name>".
// Access a specific value with e.g.: module.compute.nic_ids["app-server-mgmt-nic"]

output "vm_ids" {
  description = "Map of VM name to VM resource ID."
  value       = { for k, v in azurerm_linux_virtual_machine.main : k => v.id }
}

output "vm_names" {
  description = "Map of VM name to VM name as created in Azure (same as key, included for consistency with other outputs)."
  value       = { for k, v in azurerm_linux_virtual_machine.main : k => v.name }
}

output "private_ip_addresses" {
  description = "Map of NIC key (<vm-name>-<nic-name>) to private IP address."
  value       = { for k, v in azurerm_network_interface.main : k => v.private_ip_address }
}

output "public_ip_addresses" {
  description = "Map of NIC key (<vm-name>-<nic-name>) to public IP address (only NICs with assign_public_ip = true)."
  value       = { for k, v in azurerm_public_ip.main : k => v.ip_address }
}

output "nic_ids" {
  description = "Map of NIC key (<vm-name>-<nic-name>) to NIC resource ID."
  value       = { for k, v in azurerm_network_interface.main : k => v.id }
}

output "nic_names" {
  description = "Map of NIC key (<vm-name>-<nic-name>) to NIC name as created in Azure."
  value       = { for k, v in azurerm_network_interface.main : k => v.name }
}

output "ssh_commands" {
  description = "Map of NIC key (<vm-name>-<nic-name>) to ready-to-use SSH command (only NICs with a public IP)."
  // Build the SSH command using the admin username from var.vms and the public IP address from azurerm_public_ip.main. 
  // Only include NICs that have assign_public_ip = true.
  // The identity file path is intentionally left as a placeholder rather than sourced from a variable.
  // Accepting a file path as input would cause it to appear in Terraform state, plan output, and logs — making it easy to accidentally 
  // expose where your private keys live. Fill in the path yourself after copying the command.
  // Also, a separate variable for the path that is only used here is unnecessary complexity, so just keep it simple (KISS).
  value = {
    for k, v in local.nics : k => "ssh -i <path/to/private/key> ${var.vms[v.vm_name].admin_username}@${azurerm_public_ip.main[k].ip_address}"
    if v.assign_public_ip
  }
}

output "local_formatted_nics" {
  description = "The local.nics map, included as an output for debugging/visibility purposes."
  value       = local.nics
}
