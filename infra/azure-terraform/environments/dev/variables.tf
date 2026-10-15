variable "subscription_id" {
  description = "ID de la suscripción de Azure (Visual Studio Enterprise)"
  type        = string
  default     = "d831592b-f94a-4a50-80d0-a266c6dd2bc3"
}

variable "location" {
  description = "Región de Azure (ej. eastus2)"
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Nombre del Resource Group principal"
  type        = string
  default     = "rg-voltera-dev"
}

variable "prefix" {
  description = "Prefijo para los nombres de los recursos"
  type        = string
  default     = "voltera-dev"
}

variable "node_vm_size" {
  description = "Tamaño de VM para AKS (Standard_B4ms tiene 4 vCPU y 16GB RAM, ideal para aguantar Istio + Knative Serving y Eventing)"
  type        = string
  default     = "Standard_B4ms"
}

variable "enable_auto_scaling" {
  description = "Habilitar auto-scaling en AKS"
  type        = bool
  default     = false
}

variable "node_count" {
  description = "Cantidad fija o inicial de nodos"
  type        = number
  default     = 1
}

variable "max_pods" {
  description = "Máximo número de pods por nodo (FinOps: 80 en 1 solo nodo)"
  type        = number
  default     = 80
}

variable "daily_quota_gb" {
  description = "Límite diario de ingesta en Log Analytics en GB (FinOps)"
  type        = number
  default     = 0.5
}

variable "tags" {
  description = "Etiquetas comunes para seguimiento de costos y cumplimiento de Azure Policy"
  type        = map(string)
  default = {
    ApplicationType = "Voltera"
    Owner           = "cbenitezm"
    Environment     = "Test"
    Project         = "Voltera-EnergyTech"
    ManagedBy       = "Terraform"
    FinOpsTier      = "VS-Enterprise-Credit-Optimized"
  }
}
