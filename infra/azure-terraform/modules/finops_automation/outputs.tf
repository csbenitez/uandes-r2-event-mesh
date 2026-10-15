output "automation_account_id" {
  description = "ID de la Azure Automation Account"
  value       = azurerm_automation_account.auto.id
}

output "automation_account_name" {
  description = "Nombre de la Azure Automation Account"
  value       = azurerm_automation_account.auto.name
}

output "stop_runbook_name" {
  description = "Nombre del Runbook de apagado"
  value       = azurerm_automation_runbook.stop_aks.name
}

output "start_runbook_name" {
  description = "Nombre del Runbook de encendido"
  value       = azurerm_automation_runbook.start_aks.name
}
