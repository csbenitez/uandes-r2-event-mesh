variable "resource_group_name" {
  description = "Nombre del Resource Group"
  type        = string
}

variable "location" {
  description = "Región de Azure"
  type        = string
}

variable "prefix" {
  description = "Prefijo para los recursos"
  type        = string
}

variable "aks_cluster_id" {
  description = "ID del clúster AKS"
  type        = string
}

variable "aks_cluster_name" {
  description = "Nombre del clúster AKS"
  type        = string
}

variable "tags" {
  description = "Etiquetas comunes"
  type        = map(string)
  default     = {}
}
