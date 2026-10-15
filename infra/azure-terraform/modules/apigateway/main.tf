resource "azurerm_api_management" "apim" {
  name                = "${var.prefix}-apim"
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email

  # FinOps Crítico: SKU Consumption = $0 de costo fijo mensual.
  # El nivel Developer cuesta ~$50 USD/mes, Consumption es 100% serverless.
  sku_name = "Consumption_0"

  tags = var.tags
}
