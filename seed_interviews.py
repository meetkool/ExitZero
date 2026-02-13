import requests
import random
from datetime import datetime, timedelta
import json
import time

BASE_API_URL = "https://biznuz.mockpeer.me/api/v1"
PB_URL = "https://biznuz.mockpeer.me"

ADMIN_EMAIL = "iitjeemeet@gmail.com"
ADMIN_PASS = "Kooljool"

USER_EMAIL = "kooljool@gmail.com"
USER_PASS = "password123"
USER_NAME = "Kool Jool"


def main():
    print("Preparing user...")
    # Register if needed
    try:
        reg_resp = requests.post(f"{BASE_API_URL}/auth/register", json={
            "email": USER_EMAIL,
            "password": USER_PASS,
            "name": USER_NAME
        })
        if reg_resp.status_code in [200, 201]:
            print("User registered.")
        else:
            print(f"Registration checked/failed: {reg_resp.text}")
    except Exception as e:
        print(f"Error checking registration: {e}")

def get_user_token():
    resp = requests.post(f"{BASE_API_URL}/auth/token", data={
        "username": USER_EMAIL,
        "password": USER_PASS
    })
    if resp.status_code == 200:
        return resp.json()["access_token"]
    print(f"Login failed: {resp.text}")
    return None

def main():
    print("Preparing user...")
    # Register if needed
    try:
        reg_resp = requests.post(f"{BASE_API_URL}/auth/register", json={
            "email": USER_EMAIL,
            "password": USER_PASS,
            "name": USER_NAME
        })
        if reg_resp.status_code in [200, 201]:
            print("User registered.")
        else:
            print(f"Registration checked/failed: {reg_resp.text}")
    except Exception as e:
        print(f"Error checking registration: {e}")

    print("Getting user token...")
    user_token = get_user_token()
    if not user_token:
        return

    print("Generating 20 past/future interviews...")
    success_count = 0
    
    # Generate some future and some past
    for i in range(20):
        # -10 to +10 days
        days_offset = random.randint(-10, 10)
        
        # 1. Create via FastAPI
        start_time = datetime.utcnow() + timedelta(days=days_offset, hours=random.randint(1, 5))
        
        platforms = ["Google Meet", "Zoom", "Teams"]
        companies = ["Google", "Meta", "Amazon", "Netflix", "Apple", "Microsoft", "Uber", "Airbnb"]
        
        data = {
            "title": f"Mock Interview - {random.choice(['System Design', 'Coding', 'Behavioral'])}",
            "company": random.choice(companies),
            "start_time": start_time.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "time_zone": "UTC",
            "duration_minutes": 60,
            "platform": random.choice(platforms),
            "role": random.choice(["SDE-1", "SDE-2", "Engineering Manager", "Product Manager"]),
            "stake_amount": 50,
            "is_mock": True,
            "notes": "Generated interview data.",
            "reminders": []
        }
        
        headers = {
            "Authorization": f"Bearer {user_token}",
            "Content-Type": "application/json"
        }
        
        resp = requests.post(f"{BASE_API_URL}/interviews/", json=data, headers=headers)
        
        if resp.status_code in [200, 201]:
            print(f"Created interview for {start_time.date()}")
            success_count += 1
        else:
            print(f"Failed to create interview: {resp.text}")
            
    print(f"Done. Successfully created {success_count} interviews.")

if __name__ == "__main__":
    main()

