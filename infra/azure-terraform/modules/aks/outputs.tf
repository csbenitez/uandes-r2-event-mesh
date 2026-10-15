output "cluster_id" {
  description = "ID del clúster AKS"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "cluster_name" {
  description = "Nombre del clúster AKS"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "kube_config_raw" {
  description = "Kubeconfig raw para conectarse al clúster"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "oidc_issuer_url" {
  description = "URL del OIDC issuer para Workload Identity"
  value       = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}

output "principal_id" {
  description = "Principal ID de la Managed Identity del clúster"
  value       = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

output "node_resource_group" {
  description = "Resource Group creado automáticamente por Azure para los nodos (MC_...)"
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}
