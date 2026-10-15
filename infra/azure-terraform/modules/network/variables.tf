variable "resource_group_name" {
  description = "Nombre del Resource Group principal"
  type        = string
}

variable "location" {
  description = "Región de Azure (ej. eastus2)"
  type        = string
}

variable "prefix" {
  description = "Prefijo para los nombres de recursos"
  type        = string
}

variable "vnet_cidr" {
  description = "CIDR para la VNet principal"
  type        = string
  default     = "10.10.0.0/16"
}

variable "aks_subnet_cidr" {
  description = "CIDR para la Subred de AKS"
  type        = string
  default     = "10.10.1.0/24"
}

variable "tags" {
  description = "Etiquetas comunes"
  type        = map(string)
  default     = {}
}
