# Misión 03 · Orders

Dedica 20 minutos a completar Orders; Payments e Inventory se entregaron preparados para el recorrido básico. Consulta README.md para los pasos y conserva esos consumidores en tu repositorio.

Orders recibe un evento HTTP cuyo body contiene orderId, customerId y total. Guarda esos campos, status CREATED y createdAt en ORDERS_TABLE; publica source com.cloudopsarena.orders y detail-type OrderCreated en EVENT_BUS_NAME y devuelve statusCode 201 con la orden en el body. Respeta AWS_ENDPOINT_URL y AWS_REGION.

Agrega el workflow de esta descarga y ejecútalo desde Actions con la misión 03 activa. El juez usa recursos efímeros de DynamoDB, EventBridge y SQS dentro de una VM e invoca handlers sin privilegios; no actualiza tu despliegue persistente. Las garantías de duplicados corresponden a misión 04.
