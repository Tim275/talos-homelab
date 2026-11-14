data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "unseal" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_key_vault" "unseal" {
  name                       = var.key_vault_name
  resource_group_name        = azurerm_resource_group.unseal.name
  location                   = azurerm_resource_group.unseal.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 90
}

resource "azurerm_role_assignment" "deployer" {
  scope                = azurerm_key_vault.unseal.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_key" "openbao" {
  depends_on = [azurerm_role_assignment.deployer]

  name         = "openbao-unseal"
  key_vault_id = azurerm_key_vault.unseal.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["wrapKey", "unwrapKey"]
}

resource "azuread_application" "openbao" {
  display_name = "homelab-openbao-unseal"
}

resource "azuread_service_principal" "openbao" {
  client_id = azuread_application.openbao.client_id
}

resource "azuread_application_password" "openbao" {
  application_id = azuread_application.openbao.id
  display_name   = "openbao"
  end_date       = timeadd(plantimestamp(), "87600h")

  lifecycle {
    ignore_changes = [end_date]
  }
}

resource "azurerm_role_assignment" "openbao" {
  scope                = azurerm_key_vault_key.openbao.resource_versionless_id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azuread_service_principal.openbao.object_id
}
