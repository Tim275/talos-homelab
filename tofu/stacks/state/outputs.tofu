output "storage_account_name" {
  value = azurerm_storage_account.state.name
}

output "container_name" {
  value = azurerm_storage_container.tfstate.name
}

output "resource_group" {
  value = azurerm_resource_group.state.name
}
