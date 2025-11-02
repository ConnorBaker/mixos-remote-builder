resource "azurerm_virtual_network" "mixos_network" {
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.mixos_rg.location
  name                = "mixos_network"
  resource_group_name = azurerm_resource_group.mixos_rg.name
}

resource "azurerm_subnet" "mixos_subnet" {
  address_prefixes     = ["10.0.2.0/24"]
  name                 = "mixos_subnet"
  resource_group_name  = azurerm_resource_group.mixos_rg.name
  virtual_network_name = azurerm_virtual_network.mixos_network.name
}

resource "azurerm_network_interface" "mixos_nic" {
  name                = "mixos_nic"
  location            = azurerm_resource_group.mixos_rg.location
  resource_group_name = azurerm_resource_group.mixos_rg.name

  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "mixos_nic_ip"
    primary                       = true
    subnet_id                     = azurerm_subnet.mixos_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_storage_account" "mixos_boot_diag" {
  name                            = "mixosbootdiag"
  location                        = azurerm_resource_group.mixos_rg.location
  resource_group_name             = azurerm_resource_group.mixos_rg.name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true
}

# TODO: Why was there a mixos_vm-disk1 in the Azure subscription?

resource "azurerm_linux_virtual_machine" "mixos_vm" {
  name                = "mixos-vm"
  location            = azurerm_resource_group.mixos_rg.location
  resource_group_name = azurerm_resource_group.mixos_rg.name
  size                = "Standard_HB120rs_v3"
  eviction_policy     = "Delete"
  priority            = "Spot"

  admin_username = "notroot" # this has to be set and cannot be root

  provision_vm_agent         = false
  allow_extension_operations = false

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.mixos_boot_diag.primary_blob_endpoint
  }

  # This cannot be empty because disable_password_authentication is set
  admin_ssh_key {
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJXpenPZWADrxK4+6nFmPspmYPPniI3m+3PxAfjbslg+"
    username   = "notroot"
  }

  network_interface_ids = [
    azurerm_network_interface.mixos_nic.id
  ]

  os_disk {
    caching              = "ReadOnly"
    storage_account_type = "Standard_LRS"
  }

  source_image_id = azurerm_image.mixos.id
}
