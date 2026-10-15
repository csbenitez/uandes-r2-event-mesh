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

variable "publisher_name" {
  description = "Nombre del publisher para APIM"
  type        = string
  default     = "Voltera Energy"
}

variable "publisher_email" {
  description = "Email del publisher para APIM"
  type        = string
  default     = "admin@voltera.local"
}

variable "tags" {
  description = "Etiquetas comunes"
  type        = map(string)
  default     = {}
}
