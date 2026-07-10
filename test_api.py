import requests

schema = requests.get("http://127.0.0.1:8000/openapi.json").json()
import json
print(json.dumps(schema['paths']['/setup-password'], indent=2))
