resource "azurerm_automation_account" "auto" {
  name                = "${var.prefix}-auto-finops"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Asignar rol a la Automation Account para poder apagar y encender AKS
resource "azurerm_role_assignment" "auto_aks_contributor" {
  scope                = var.aks_cluster_id
  role_definition_name = "Azure Kubernetes Service Contributor Role"
  principal_id         = azurerm_automation_account.auto.identity[0].principal_id
}

# Runbook PowerShell para detener el clúster AKS
resource "azurerm_automation_runbook" "stop_aks" {
  name                    = "Stop-AksCluster"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.auto.name
  log_verbose             = true
  log_progress            = true
  runbook_type            = "PowerShell"

  content = <<-EOT
    param(
      [string]$ClusterName = "${var.aks_cluster_name}",
      [string]$ResourceGroupName = "${var.resource_group_name}"
    )

    Write-Output "Iniciando autenticación mediante Managed Identity..."
    Connect-AzAccount -Identity | Out-Null

    Write-Output "Deteniendo el clúster AKS $ClusterName en $ResourceGroupName para ahorrar costos..."
    Stop-AzAksCluster -Name $ClusterName -ResourceGroupName $ResourceGroupName -Force
    Write-Output "Clúster AKS detenido exitosamente."
  EOT

  tags = var.tags
}

# Runbook PowerShell para encender el clúster AKS
resource "azurerm_automation_runbook" "start_aks" {
  name                    = "Start-AksCluster"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.auto.name
  log_verbose             = true
  log_progress            = true
  runbook_type            = "PowerShell"

  content = <<-EOT
    param(
      [string]$ClusterName = "${var.aks_cluster_name}",
      [string]$ResourceGroupName = "${var.resource_group_name}"
    )

    Write-Output "Iniciando autenticación mediante Managed Identity..."
    Connect-AzAccount -Identity | Out-Null

    Write-Output "Encendiendo el clúster AKS $ClusterName en $ResourceGroupName..."
    Start-AzAksCluster -Name $ClusterName -ResourceGroupName $ResourceGroupName
    Write-Output "Clúster AKS iniciado exitosamente."
  EOT

  tags = var.tags
}

# Horario de apagado automático diario (20:00 UTC-5 = 01:00 UTC)
resource "azurerm_automation_schedule" "daily_stop" {
  name                    = "Daily-Stop-Aks-8PM"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.auto.name
  frequency               = "Day"
  interval                = 1
  start_time              = "${timeadd(timestamp(), "24h")}"
  description             = "Apaga automáticamente el clúster AKS a las 8:00 PM para ahorrar créditos VS Enterprise"
  timezone                = "America/Bogota"

  lifecycle {
    ignore_changes = [start_time]
  }
}

resource "azurerm_automation_job_schedule" "schedule_stop" {
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.auto.name
  schedule_name           = azurerm_automation_schedule.daily_stop.name
  runbook_name            = azurerm_automation_runbook.stop_aks.name

  parameters = {
    clustername       = var.aks_cluster_name
    resourcegroupname = var.resource_group_name
  }
}
