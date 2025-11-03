import requests

base_url = "http://127.0.0.1:8000"

# 1. uno solo
r1 = requests.get(f"{base_url}/items/2")
print("uno:", r1.json())


# 2. masivo
payload = {"ids": ["k", "4", "10"]}

r2 = requests.post(f"{base_url}/items/bulk", json=payload)
print(f"Tipo de r2: {type(r2)}")
print("masivo:", r2.json())

# 3. raiz
r = requests.get(base_url + "/")
print(r.json())

# 4. busqueda por ciudad
r4 = requests.get(f"{base_url}/search/items?ciudad=Lima")
print("busqueda ciudad:", r4.json())