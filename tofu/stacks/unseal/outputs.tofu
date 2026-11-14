output "vault_name" {
  value = azurerm_key_vault.unseal.name
}

output "key_name" {
  value = azurerm_key_vault_key.openbao.name
}

output "credentials" {
  sensitive = true
  value = {
    AZURE_TENANT_ID     = data.azurerm_client_config.current.tenant_id
    AZURE_CLIENT_ID     = azuread_application.openbao.client_id
    AZURE_CLIENT_SECRET = azuread_application_password.openbao.value
  }
}

output "credentials_end_date" {
  value = azuread_application_password.openbao.end_date
}
