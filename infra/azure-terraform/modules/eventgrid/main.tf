resource "azurerm_eventgrid_topic" "topic" {
  name                = "${var.prefix}-eg-topic"
  location            = var.location
  resource_group_name = var.resource_group_name

  # CloudEvents 1.0 como esquema nativo para interoperabilidad directa con Knative Event Mesh
  input_schema = "CloudEventSchemaV1_0"

  tags = var.tags
}
