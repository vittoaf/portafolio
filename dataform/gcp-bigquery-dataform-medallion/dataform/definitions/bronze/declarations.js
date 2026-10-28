// Declaración de las 3 tablas crudas en la capa Bronze
declare({
  database: dataform.projectConfig.defaultDatabase,
  schema: "bronze_layer",
  name: "raw_customers",
  description: "Tabla cruda de clientes capturada desde archivos transaccionales CSV."
});

declare({
  database: dataform.projectConfig.defaultDatabase,
  schema: "bronze_layer",
  name: "raw_products",
  description: "Tabla cruda de catálogo de productos y precios base."
});

declare({
  database: dataform.projectConfig.defaultDatabase,
  schema: "bronze_layer",
  name: "raw_orders",
  description: "Tabla cruda transaccional de ventas y pedidos."
});
