locals {
  # Flatten the nested nics list from each VM into a single map keyed by "<vm-name>-<nic-name>".
  #
  # Why this is needed:
  # The vms variable is designed to be fully self-contained — every VM definition including its
  # NICs lives in one place, which is the simplest interface for callers of this module.
  # However, Terraform's for_each on resources requires a flat map; it cannot iterate over
  # a nested structure (map of VMs, each with a list of NICs) directly.
  # This local bridges that gap: it transforms the nested input into the flat map that
  # azurerm_public_ip and azurerm_network_interface need, without exposing that complexity
  # to the module caller.
  # This small added complexity allows a much cleaner and more intuitive module interface, 
  # where all information about a VM is in one place (the vms var) and there's no need to correlate 
  # separate variables for NICs, images, etc.
  nics = {
    for pair in flatten([
      for vm_name, vm in var.vms : [
        for nic in vm.nics : {
          key              = "${vm_name}-${nic.name}"
          vm_name          = vm_name
          subnet_id        = nic.subnet_id
          assign_public_ip = nic.assign_public_ip
        }
      ]
    ]) : pair.key => pair
  }
}
