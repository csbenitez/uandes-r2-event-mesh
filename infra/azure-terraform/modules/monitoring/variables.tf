variable "resource_group_name" {
  description = "Nombre del Resource Group"
  type        = string
}

variable "location" {
  description = "Región de Azure"
  type        = string
}

variable "prefix" {
  description = "Prefijo para los nombres de recursos"
  type        = string
}

variable "daily_quota_gb" {
  description = "Límite diario de ingesta en Log Analytics en GB (FinOps)"
  type        = number
  default     = 0.5
}

variable "tags" {
  description = "Etiquetas comunes"
  type        = map(string)
  default     = {}
}
