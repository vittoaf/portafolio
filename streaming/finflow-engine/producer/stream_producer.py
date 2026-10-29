import hashlib
import json
import os
import random
import time
from datetime import datetime, timezone
from google.cloud import pubsub_v1

PROJECT_ID = os.environ.get("PROJECT_ID")
TOPIC_ID = os.environ.get("TOPIC_ID", "finflow-transactions-main")

if not PROJECT_ID:
    raise ValueError("Variable de entorno PROJECT_ID es obligatoria.")

publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(PROJECT_ID, TOPIC_ID)

CHANNELS = ["MOBILE_APP", "WEB_PORTAL", "ATM", "POS"]
TYPES = ["TRANSFER", "PAYMENT", "WITHDRAWAL"]
STATUSES = ["COMPLETED", "PENDING", "REJECTED"]
MERCHANTS = ["Amazon", "Falabella", "Supermercados Metro", "Starbucks", "Uber"]

def generate_transaction(tx_id_override=None):
    tx_id = tx_id_override or f"tx_{hashlib.md5(f'{time.time()}_{random.random()}'.encode()).hexdigest()[:16]}"
    account_id = f"acc_pe_{random.randint(100000, 999999)}"
    customer_id = f"usr_{random.randint(1000, 9999)}"
    amount = round(random.uniform(5.0, 3500.0), 2)
    currency = "PEN"
    tx_type = random.choice(TYPES)
    channel = random.choice(CHANNELS)
    status = random.choice(STATUSES)
    merchant = random.choice(MERCHANTS)
    timestamp = datetime.now(timezone.utc).isoformat()
    
    raw_signature = f"{tx_id}|{account_id}|{amount}|{timestamp}"
    payload_hash = hashlib.sha256(raw_signature.encode()).hexdigest()

    return {
        "transaction_id": tx_id,
        "account_id": account_id,
        "customer_id": customer_id,
        "amount": amount,
        "currency": currency,
        "transaction_type": tx_type,
        "channel": channel,
        "status": status,
        "merchant_name": merchant,
        "event_timestamp": timestamp,
        "payload_hash": payload_hash
    }

def run_producer(messages_to_send=50, sleep_sec=0.5):
    print(f"[*] Publicando eventos hacia: {topic_path}...")
    cached_tx_for_duplicate = None

    for i in range(1, messages_to_send + 1):
        if i % 10 == 0 and cached_tx_for_duplicate:
            data = cached_tx_for_duplicate
            print(f" -> [{i}] Inyectando mensaje duplicado intencional: {data['transaction_id']}")
        elif i % 25 == 0:
            bad_payload = b"CORRUPTED_RAW_MESSAGE_TRIGGER_DLQ"
            publisher.publish(topic_path, bad_payload)
            print(f" -> [{i}] Inyectando mensaje corrupto para probar DLQ...")
            time.sleep(sleep_sec)
            continue
        else:
            data = generate_transaction()
            if i % 5 == 0:
                cached_tx_for_duplicate = data

        payload = json.dumps(data).encode("utf-8")
        future = publisher.publish(topic_path, payload)
        future.result()
        print(f" -> [{i}] Enviado: {data['transaction_id']} | Monto: {data['amount']} {data['currency']}")
        time.sleep(sleep_sec)

    print("[*] Simulación finalizada con éxito.")

if __name__ == "__main__":
    run_producer()
