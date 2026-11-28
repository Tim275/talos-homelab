resource "azurerm_storage_account" "offsite" {
  name                     = var.offsite_storage_account_name
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Cool"
  min_tls_version          = "TLS1_2"

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "openbao_backups" {
  name                  = "openbao-backups"
  storage_account_id    = azurerm_storage_account.offsite.id
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_management_lock" "offsite" {
  name       = "offsite"
  scope      = azurerm_storage_account.offsite.id
  lock_level = "CanNotDelete"
}

# no delete permission: the nightly copy can add and overwrite, old versions stay 30 days
data "azurerm_storage_account_blob_container_sas" "offsite_copy" {
  connection_string = azurerm_storage_account.offsite.primary_connection_string
  container_name    = azurerm_storage_container.openbao_backups.name
  https_only        = true
  start             = var.offsite_sas_start
  expiry            = var.offsite_sas_expiry

  permissions {
    read   = true
    add    = true
    create = true
    write  = true
    delete = false
    list   = true
  }
}
