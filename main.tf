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

  name                = "${each.key}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  # Dynamic: Azure assigns the public IP only when the VM boots — not at resource creation time.
  #          The address can change whenever the VM is stopped/deallocated and restarted.
  # Static:  Azure reserves and assigns the public IP at resource creation time, immediately.
  #          The address never changes for the lifetime of the resource.
  # Choice: Static — public IPs must be available immediately in Terraform state after apply.
  #   Note: unlike private IPs (which Azure assigns at NIC creation), Dynamic public IPs are only
  #   assigned when the VM boots. Terraform reads the ip_address attribute during apply — before the
  #   VM has started — so it always gets an empty string, making outputs like ssh_commands unusable.
  #   Static ensures the address is reserved and readable right after resource creation, just like
  #   private IPs are. Standard SKU is required for Static allocation.
  allocation_method       = "Static"
  sku                     = "Standard"
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
    name      = "ip-config"
    subnet_id = each.value.subnet_id
    # Dynamic: Azure automatically picks and assigns a private IP from the subnet pool when the NIC
    #          is created. The address is stable across VM stop/start but may change if the NIC is deleted and recreated.
    # Static:  You specify an exact private IP address; Azure reserves it for this NIC permanently.
    # Choice: Dynamic — private IPs are assigned at NIC creation (not at VM boot like with public IPs), so Terraform
    #   can always read the value immediately after apply. No need to manage specific addresses via Static allocation.
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
