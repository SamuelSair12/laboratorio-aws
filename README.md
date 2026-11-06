# Todo empieza con un evento · 60 minutos

Cuatro misiones: arquitectura (5 min), despliegue (15), Orders (20), resiliencia (15) y cinco minutos de cierre.

## Misión 02

1. Sube los archivos del kit a la raíz de tu repositorio sin una carpeta contenedora.
2. Vincula el repositorio en Arena y autoriza su acceso con la GitHub App.
3. Configura ARENA_EVENT_ID en Settings → Secrets and variables → Actions → Variables con el identificador que muestra Arena.
4. Al final de .github/workflows/terraform-lab.yml, descomenta el paso de despliegue:

```yaml
      - name: Desplegar la infraestructura en Arena
        env:
          ARENA_OPERATION: deploy
        run: python3 "$RUNNER_TEMP/arena-request.py"
```

Ejecuta Actions → Validar y desplegar laboratorio en Arena. El plan solo valida; el deploy verificado concede 14 puntos técnicos y publica tu inventario. Vincular el repositorio concede un punto separado. No ejecutes Terraform directamente en GitHub ni agregues claves AWS.

## Misión 03

Completa solo Orders. Payments e Inventory ya procesan órdenes nuevas; su protección frente a duplicados queda para misión 04. El juez runtime comprueba tus handlers con recursos efímeros; todavía no actualiza las Lambdas de tu playground persistente.

## Misión 04

Revisa las escrituras de idempotencia de ambos consumidores. Usa una condición para aceptar una operación nueva una sola vez y trata ConditionalCheckFailedException como duplicado válido. Conserva OPERATIONS_URL después de aceptar la operación y FAIL_PAYMENTS antes de registrar nada. El juez verifica reintentos y DLQ con recursos de prueba aislados.

Conserva tu código al descargar guías posteriores. Las entregas previas no vuelven a sumar puntos. Los archivos se mantienen bajo game-packs/aws-event-driven para ser compatibles con los workflows y validadores existentes.
