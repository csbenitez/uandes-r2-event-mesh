output "apim_id" {
  description = "ID de la instancia de API Management"
  value       = azurerm_api_management.apim.id
}

output "apim_name" {
  description = "Nombre de API Management"
  value       = azurerm_api_management.apim.name
}

output "gateway_url" {
  description = "URL del Gateway de APIM"
  value       = azurerm_api_management.apim.gateway_url
}
