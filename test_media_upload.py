import requests
import json
import time

base_url = 'http://127.0.0.1:8000/api'
email = f'test_{int(time.time() * 1000)}@example.com'
password = 'password123'

# Register
reg_res = requests.post(f'{base_url}/register', json={
    'first_name': 'Test',
    'last_name': 'User',
    'email': email,
    'phone_number': f'12345{str(int(time.time() * 1000))[-6:]}',
    'password': password,
    'password_confirmation': password,
}, headers={'Accept': 'application/json'})

print("Reg:", reg_res.text)
token = reg_res.json().get('token')

if token:
    headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/json'}
    
    # Create a 3MB dummy file
    with open('dummy_large.png', 'wb') as f:
        f.write(b'\x00' * (3 * 1024 * 1024))
        
    files = {'media': ('dummy_large.png', open('dummy_large.png', 'rb'), 'image/png')}
    data = {
        'type': 'harassment',
        'description': 'Test Description with media',
        'location_text': "123 Main street, Anytown", 
        'latitude': "30.0444",
        'longitude': "31.2357",
    }
    
    upload_res = requests.post(f'{base_url}/incidents/create', headers=headers, data=data, files=files)
    print("Upload large media:", upload_res.text)
