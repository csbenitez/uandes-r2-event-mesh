resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.prefix}-law"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  # FinOps Crítico: Limita la ingesta a 0.5 GB por día para evitar cobros sorpresa
  daily_quota_gb = var.daily_quota_gb

  tags = var.tags
}

resource "azurerm_application_insights" "appinsights" {
  name                = "${var.prefix}-appinsights"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.law.id
  application_type    = "web"

  tags = var.tags
}
