output "topic_id" {
  description = "ID del tópico de Event Grid"
  value       = azurerm_eventgrid_topic.topic.id
}

output "topic_name" {
  description = "Nombre del tópico de Event Grid"
  value       = azurerm_eventgrid_topic.topic.name
}

output "endpoint" {
  description = "Endpoint HTTPS para publicación de eventos"
  value       = azurerm_eventgrid_topic.topic.endpoint
}

output "primary_access_key" {
  description = "Clave primaria de acceso a Event Grid"
  value       = azurerm_eventgrid_topic.topic.primary_access_key
  sensitive   = true
}
