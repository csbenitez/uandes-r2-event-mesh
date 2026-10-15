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

variable "subnet_id" {
  description = "ID de la subred donde residirán los nodos"
  type        = string
}

variable "node_vm_size" {
  description = "Tamaño de la VM del node pool (Standard_B4ms tiene 4 vCPU y 16GB RAM, ideal para aguantar Istio + Knative a bajo costo)"
  type        = string
  default     = "Standard_B4ms"
}

variable "node_count" {
  description = "Número inicial de nodos"
  type        = number
  default     = 1
}

variable "enable_auto_scaling" {
  description = "Habilitar auto-escalado"
  type        = bool
  default     = true
}

variable "min_count" {
  description = "Mínimo de nodos en auto-escalado"
  type        = number
  default     = 1
}

variable "max_count" {
  description = "Máximo de nodos en auto-escalado"
  type        = number
  default     = 2
}

variable "os_disk_size_gb" {
  description = "Tamaño del disco de SO en GB"
  type        = number
  default     = 64
}

variable "log_analytics_workspace_id" {
  description = "ID del Log Analytics Workspace para integración de monitoreo"
  type        = string
  default     = null
}

variable "max_pods" {
  description = "Máximo número de pods por nodo (FinOps: 80 para soportar Istio + Knative en 1 solo nodo)"
  type        = number
  default     = 80
}

variable "tags" {
  description = "Etiquetas comunes"
  type        = map(string)
  default     = {}
}
