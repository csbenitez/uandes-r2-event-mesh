output "resource_group_name" {
  description = "Nombre del Resource Group"
  value       = azurerm_resource_group.rg.name
}

output "resource_group_id" {
  description = "ID del Resource Group"
  value       = azurerm_resource_group.rg.id
}

output "location" {
  description = "Ubicación del Resource Group"
  value       = azurerm_resource_group.rg.location
}

output "vnet_id" {
  description = "ID de la Virtual Network"
  value       = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  description = "Nombre de la Virtual Network"
  value       = azurerm_virtual_network.vnet.name
}

output "aks_subnet_id" {
  description = "ID de la Subred para AKS"
  value       = azurerm_subnet.aks_subnet.id
}
