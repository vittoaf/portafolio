import argparse
import json
import os
import random
import time
import uuid
from datetime import datetime, timezone
from google.cloud import pubsub_v1

PRODUCT_CATALOG = [
    {"product_id": "PROD-101", "name": "Mechanical Keyboard", "price": 85.50},
    {"product_id": "PROD-102", "name": "Wireless Mouse", "price": 45.00},
    {"product_id": "PROD-103", "name": "27-inch 4K Monitor", "price": 320.00},
    {"product_id": "PROD-104", "name": "USB-C Multiport Hub", "price": 35.20},
    {"product_id": "PROD-105", "name": "Noise Cancelling Headphones", "price": 199.99},
]

STATUS_CHOICES = ["COMPLETED", "PENDING", "CANCELLED"]
CURRENCY = "USD"


def generate_simulated_order(existing_order_id=None):
    """Genera un evento de orden en formato JSON compatible con BigQuery."""
    order_id = existing_order_id if existing_order_id else f"ORD-{uuid.uuid4().hex[:10].upper()}"
    customer_id = f"CUST-{random.randint(1000, 9999)}"
    
    num_items = random.randint(1, 3)
    selected_products = random.sample(PRODUCT_CATALOG, num_items)
    items = []
    total = 0.0

    for prod in selected_products:
        qty = random.randint(1, 2)
        price = prod["price"]
        items.append({
            "product_id": prod["product_id"],
            "quantity": qty,
            "unit_price": price
        })
        total += qty * price

    now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")

    return {
        "order_id": order_id,
        "customer_id": customer_id,
        "event_timestamp": now_iso,
        "published_at": now_iso,
        "status": random.choice(STATUS_CHOICES),
        "total_amount": round(total, 2),
        "currency": CURRENCY,
        "items": items,
        "raw_metadata": json.dumps({"source": "stream_simulator", "version": "1.0.0"})
    }


def generate_corrupt_order():
    """Genera un evento con tipos inválidos para forzar el desvío hacia la DLQ."""
    return {
        "order_id": f"CORRUPT-{uuid.uuid4().hex[:8].upper()}",
        "customer_id": "CUST-ERROR",
        "event_timestamp": "TIMESTAMP_INVALIDO",       # Rompe el tipo TIMESTAMP
        "published_at": "FECHA_MALFORMADA",             # Rompe el tipo TIMESTAMP
        "status": "CORRUPT_PAYLOAD",
        "total_amount": "CIEN_DOLARES_TEXTO",           # Rompe el tipo NUMERIC
        "currency": "USD",
        "items": "NO_ES_UN_ARRAY_RECORD",               # Rompe el tipo REPEATED RECORD
        "raw_metadata": json.dumps({"source": "dlq_test_injection"})
    }


def run_producer(project_id: str, topic_id: str, count: int, interval: float, 
                 simulate_duplicates: bool, simulate_corrupt: bool):
    publisher = pubsub_v1.PublisherClient()
    topic_path = publisher.topic_path(project_id, topic_id)

    print(f"[*] Conectando con topico: {topic_path}")
    print(f"[*] Modo: {'Continuo (Infinito)' if count <= 0 else f'{count} eventos'}")
    print(f"[*] Intervalo entre mensajes: {interval} seg")
    print(f"[*] Inyeccion de duplicados: {simulate_duplicates}")
    print(f"[*] Inyeccion de mensajes corruptos (DLQ test): {simulate_corrupt}\n")

    sent_count = 0
    cached_order_ids = []

    try:
        while True:
            if count > 0 and sent_count >= count:
                break

            # 1. Caso corrupto para disparar la DLQ
            if simulate_corrupt and random.random() < 0.20:
                order_data = generate_corrupt_order()
                print(f"[INYECCION DLQ] Enviando payload invalido: {order_data['order_id']}")
            
            # 2. Caso duplicado para probar la idempotencia en Silver
            elif simulate_duplicates and len(cached_order_ids) > 0 and random.random() < 0.25:
                order_id_to_use = random.choice(cached_order_ids)
                order_data = generate_simulated_order(existing_order_id=order_id_to_use)
                print(f"[DUPLICADO INTENCIONAL] Reenviando Order ID: {order_id_to_use}")
            
            # 3. Flujo normal
            else:
                order_data = generate_simulated_order()
                cached_order_ids.append(order_data["order_id"])
                if len(cached_order_ids) > 20:
                    cached_order_ids.pop(0)

            data_str = json.dumps(order_data)
            data_bytes = data_str.encode("utf-8")
            future = publisher.publish(topic_path, data=data_bytes)
            message_id = future.result()

            sent_count += 1
            print(f"[{sent_count}] Publicado: {order_data['order_id']} | MsgID: {message_id}")

            time.sleep(interval)

    except KeyboardInterrupt:
        print("\n[!] Streaming detenido manualmente por el usuario.")
    finally:
        print(f"[*] Proceso finalizado. Total de eventos enviados: {sent_count}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Simulador de eventos Streaming para Pub/Sub -> BigQuery")
    parser.add_argument("--project_id", type=str, required=True, help="GCP Project ID")
    parser.add_argument("--topic_id", type=str, default="top_ecommerce_orders", help="Nombre del topico de Pub/Sub")
    parser.add_argument("--count", type=int, default=20, help="Cantidad de eventos a emitir (0 para loop infinito)")
    parser.add_argument("--interval", type=float, default=1.0, help="Segundos entre cada publicacion")
    parser.add_argument("--simulate_duplicates", action="store_true", help="Habilita envio intencional de registros duplicados")
    parser.add_argument("--simulate_corrupt", action="store_true", help="Habilita envio intencional de datos con error para probar la DLQ")

    args = parser.parse_args()
    run_producer(
        project_id=args.project_id,
        topic_id=args.topic_id,
        count=args.count,
        interval=args.interval,
        simulate_duplicates=args.simulate_duplicates,
        simulate_corrupt=args.simulate_corrupt
    )