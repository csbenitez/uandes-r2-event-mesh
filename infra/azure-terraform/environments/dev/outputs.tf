output "resource_group_name" {
  description = "Nombre del Resource Group"
  value       = module.network.resource_group_name
}

output "aks_cluster_name" {
  description = "Nombre del clúster AKS"
  value       = module.aks.cluster_name
}

output "aks_connect_command" {
  description = "Comando para configurar kubectl con el clúster AKS"
  value       = "az aks get-credentials --resource-group ${module.network.resource_group_name} --name ${module.aks.cluster_name} --overwrite-existing"
}

output "eventgrid_topic_endpoint" {
  description = "Endpoint del tópico Event Grid"
  value       = module.eventgrid.endpoint
}

output "eventgrid_primary_key" {
  description = "Clave primaria del tópico Event Grid"
  value       = module.eventgrid.primary_access_key
  sensitive   = true
}

output "apim_gateway_url" {
  description = "URL del Gateway de Azure API Management"
  value       = module.apigateway.gateway_url
}

output "app_insights_connection_string" {
  description = "Connection String de Application Insights"
  value       = module.monitoring.app_insights_connection_string
  sensitive   = true
}

output "finops_stop_command" {
  description = "Comando rápido de PowerShell para apagar el clúster AKS y suspender el cómputo"
  value       = "az aks stop --resource-group ${module.network.resource_group_name} --name ${module.aks.cluster_name} --no-wait"
}

output "finops_start_command" {
  description = "Comando rápido de PowerShell para reanudar el clúster AKS"
  value       = "az aks start --resource-group ${module.network.resource_group_name} --name ${module.aks.cluster_name} --no-wait"
}
