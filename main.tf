# =============================================================================
# terraform-azurerm-compute - Azure Linux VM Stack
# =============================================================================
# Creates Linux VMs with full network connectivity:
#   - Public IPs  (only for NICs with assign_public_ip = true)
#   - Network Interfaces (one per NIC entry, named <vm-name>-<nic-name>)
#   - Linux Virtual Machines (one per entry in var.vms)
#
# Subnet IDs are provided by the caller — typically from the outputs of the
# terraform-azurerm-network module (e.g. module.network.subnet_ids["my-subnet"]).
# =============================================================================

# Public IP — only for NICs that need external access (e.g. mgmt NIC on a jump host)
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
resource "azurerm_public_ip" "main" {
  # Use the local.nics map, which is a flattened version of the nested NIC definitions in var.vms for easy iteration
  for_each = { for k, v in local.nics : k => v if v.assign_public_ip }

  name                    = "${each.key}-pip"
  location                = var.location
  resource_group_name     = var.resource_group_name
  allocation_method       = "Dynamic"
  sku                     = "Basic"
  ip_version              = "IPv4"
  idle_timeout_in_minutes = 4

  tags = var.tags
}

# Network Interface — one per NIC entry across all VMs, named <vm-name>-<nic-name>
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface
resource "azurerm_network_interface" "main" {
  # Use the local.nics map, which is a flattened version of the nested NIC definitions in var.vms for easy iteration
  for_each = local.nics

  name                = each.key
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ip-config"
    subnet_id                     = each.value.subnet_id
    private_ip_address_allocation = "Dynamic"
    # Attach public IP only for NICs that have one, null otherwise
    public_ip_address_id = each.value.assign_public_ip ? azurerm_public_ip.main[each.key].id : null
  }

  tags = var.tags
}

# Linux Virtual Machine — one per entry in var.vms
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine
resource "azurerm_linux_virtual_machine" "main" {
  for_each = var.vms

  name                = each.key
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = each.value.size
  admin_username      = each.value.admin_username

  # Disable password authentication for security — SSH keys only
  disable_password_authentication = true

  # All NICs for this VM, resolved from the nics list by name
  network_interface_ids = [
    for nic in each.value.nics : azurerm_network_interface.main["${each.key}-${nic.name}"].id
  ]

  # Add the SSH public key for authentication via the corresponding private key
  admin_ssh_key {
    username   = each.value.admin_username
    public_key = each.value.ssh_public_key
  }

  os_disk {
    caching              = each.value.os_disk.caching
    storage_account_type = each.value.os_disk.storage_account_type
    disk_size_gb         = each.value.os_disk.disk_size_gb
  }

  source_image_reference {
    publisher = each.value.image.publisher
    offer     = each.value.image.offer
    sku       = each.value.image.sku
    version   = each.value.image.version
  }

  computer_name = each.key # Hostname used for the VM

  tags = var.tags
}
