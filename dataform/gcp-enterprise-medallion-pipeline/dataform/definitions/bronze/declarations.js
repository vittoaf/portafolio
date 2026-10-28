declare({
  database: dataform.projectConfig.defaultProject,
  schema: "bronze_layer",
  name: "raw_customers",
  description: "Capa Bronze: Datos crudos de clientes ingestados desde CSV/fuente externa."
});

declare({
  database: dataform.projectConfig.defaultProject,
  schema: "bronze_layer",
  name: "raw_products",
  description: "Capa Bronze: Catalogo crudo de productos e inventario."
});

declare({
  database: dataform.projectConfig.defaultProject,
  schema: "bronze_layer",
  name: "raw_orders",
  description: "Capa Bronze: Cabeceras transaccionales de ordenes crudas."
});

declare({
  database: dataform.projectConfig.defaultProject,
  schema: "bronze_layer",
  name: "raw_order_items",
  description: "Capa Bronze: Lineas de detalle crudas por cada orden de compra."
});

declare({
  database: dataform.projectConfig.defaultProject,
  schema: "bronze_layer",
  name: "raw_payments",
  description: "Capa Bronze: Transacciones de pago y liquidacion crudas."
});
