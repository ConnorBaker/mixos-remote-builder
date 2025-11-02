resource "azurerm_storage_account" "vhd" {
  name                            = var.storage_account_name
  resource_group_name             = azurerm_resource_group.mixos_rg.name
  location                        = azurerm_resource_group.mixos_rg.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true
}

resource "azurerm_storage_container" "vhds" {
  name               = "vhds"
  storage_account_id = azurerm_storage_account.vhd.id
}

resource "azurerm_storage_blob" "vhd" {
  name                   = var.vhd_blob_name
  storage_account_name   = azurerm_storage_account.vhd.name
  storage_container_name = azurerm_storage_container.vhds.name
  type                   = "Page"
  source                 = var.vhd_absolute_path
  content_type           = "application/octet-stream"
}

resource "azurerm_image" "mixos" {
  name                = var.image_name
  resource_group_name = azurerm_resource_group.mixos_rg.name
  location            = azurerm_resource_group.mixos_rg.location
  hyper_v_generation  = var.image_hyper_v_generation
  depends_on          = [azurerm_storage_blob.vhd]

  os_disk {
    os_type      = "Linux"
    os_state     = "Generalized"
    storage_type = "Standard_LRS"
    caching      = "ReadOnly"
    blob_uri     = azurerm_storage_blob.vhd.url
  }
}
