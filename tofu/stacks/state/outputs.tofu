output "storage_account_name" {
  value = azurerm_storage_account.state.name
}

output "container_name" {
  value = azurerm_storage_container.tfstate.name
}

output "resource_group" {
  value = azurerm_resource_group.state.name
}

output "offsite_sas_url" {
  value     = "${azurerm_storage_account.offsite.primary_blob_endpoint}${azurerm_storage_container.openbao_backups.name}${data.azurerm_storage_account_blob_container_sas.offsite_copy.sas}"
  sensitive = true
}
