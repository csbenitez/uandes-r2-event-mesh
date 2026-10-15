output "workspace_id" {
  description = "ID del Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.law.id
}

output "workspace_name" {
  description = "Nombre del Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.law.name
}

output "app_insights_id" {
  description = "ID de Application Insights"
  value       = azurerm_application_insights.appinsights.id
}

output "app_insights_instrumentation_key" {
  description = "Instrumentation Key de Application Insights"
  value       = azurerm_application_insights.appinsights.instrumentation_key
  sensitive   = true
}

output "app_insights_connection_string" {
  description = "Connection String de Application Insights"
  value       = azurerm_application_insights.appinsights.connection_string
  sensitive   = true
}
