import requests
import random
from datetime import datetime, timedelta
import json
import time

BASE_API_URL = "http://localhost:8000/api/v1"
PB_URL = "http://localhost:8090"

ADMIN_EMAIL = "iitjeemeet@gmail.com"
ADMIN_PASS = "Kooljool"

USER_EMAIL = "kooljool@gmail.com"
USER_PASS = "password123"
USER_NAME = "Kool Jool"

def get_admin_token():
    try:
        # PB v0.23+ might use _superusers collection for admin auth, 
        # but docker-compose shows POCKETBASE_ADMIN_... usually means classic admin or superuser.
        # Let's try /api/admins/auth-with-password (old) or /api/collections/_superusers/auth-with-password (new)
        
        # Try new way (superuser)
        url = f"{PB_URL}/api/collections/_superusers/auth-with-password"
        resp = requests.post(url, json={"identity": ADMIN_EMAIL, "password": ADMIN_PASS})
        
        if resp.status_code == 200:
            return resp.json()["token"]
            
        # Try old way (admin)
        url = f"{PB_URL}/api/admins/auth-with-password"
        resp = requests.post(url, json={"identity": ADMIN_EMAIL, "password": ADMIN_PASS})
        
        if resp.status_code == 200:
            return resp.json()["token"]
            
        print(f"Failed to get admin token: {resp.text}")
        return None
    except Exception as e:
        print(f"Error getting admin token: {e}")
        return None

def prepare_user(admin_token):
    headers = {"Authorization": admin_token}
    
    # Check if user exists
    # Filter by email
    resp = requests.get(f"{PB_URL}/api/collections/users/records", 
                        headers=headers, 
                        params={"filter": f'email="{USER_EMAIL}"'})
                        
    if resp.status_code != 200:
        print(f"Failed to query users: {resp.text}")
        return None

    data = resp.json()
    items = data.get("items", [])
    
    if items:
        # User exists, update password
        user_id = items[0]["id"]
        print(f"User {USER_EMAIL} found (ID: {user_id}). updating password...")
        update_resp = requests.patch(
            f"{PB_URL}/api/collections/users/records/{user_id}",
            headers=headers,
            json={"password": USER_PASS, "passwordConfirm": USER_PASS}
        )
        if update_resp.status_code == 200:
            print("Password updated.")
            return True
        else:
            print(f"Failed to update password: {update_resp.text}")
            return False
    else:
        # Create user via FastAPI register to handle all side effects (coins etc)
        print(f"User {USER_EMAIL} not found. Registering...")
        reg_resp = requests.post(f"{BASE_API_URL}/auth/register", json={
            "email": USER_EMAIL,
            "password": USER_PASS,
            "name": USER_NAME
        })
        if reg_resp.status_code in [200, 201]:
            print("User registered.")
            return True
        else:
            print(f"Registration failed: {reg_resp.text}")
            return False

def get_user_token():
    resp = requests.post(f"{BASE_API_URL}/auth/token", data={
        "username": USER_EMAIL,
        "password": USER_PASS
    })
    if resp.status_code == 200:
        return resp.json()["access_token"]
    print(f"Login failed: {resp.text}")
    return None

def create_and_update_interview(user_token, admin_token, date_offset):
    # 1. Create via FastAPI
    start_time = datetime.utcnow() - timedelta(days=date_offset, hours=random.randint(1, 5))
    
    platforms = ["Google Meet", "Zoom", "Teams"]
    companies = ["Google", "Meta", "Amazon", "Netflix", "Apple", "Microsoft", "Uber", "Airbnb"]
    
    data = {
        "title": f"Mock Interview - {random.choice(['System Design', 'Coding', 'Behavioral'])}",
        "company": random.choice(companies),
        "start_time": start_time.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "time_zone": "UTC",
        "duration_minutes": 60,
        "platform": random.choice(platforms),
        "stake_amount": 50,
        "is_mock": True,
        "notes": "Generated past interview data.",
        "reminders": []
    }
    
    headers = {
        "Authorization": f"Bearer {user_token}",
        "Content-Type": "application/json"
    }
    
    resp = requests.post(f"{BASE_API_URL}/interviews/", json=data, headers=headers)
    
    if resp.status_code not in [200, 201]:
        print(f"Failed to create interview: {resp.text}")
        return False
        
    interview_id = resp.json()['id']
    print(f"Created interview ID: {interview_id} for {start_time.date()}")
    
    # 2. Update status via PocketBase Admin
    if date_offset > 0:
        patch_resp = requests.patch(
            f"{PB_URL}/api/collections/interviews/records/{interview_id}",
            json={"status": "completed"},
            headers={"Authorization": admin_token}
        )
        if patch_resp.status_code == 200:
            print(f"  -> Status set to 'completed'")
        else:
            print(f"  -> Failed to update status: {patch_resp.text}")
            
    return True

def main():
    print("Getting admin token...")
    admin_token = get_admin_token()
    if not admin_token:
        print("Could not get Admin token. Aborting.")
        return

    print("Preparing user...")
    if not prepare_user(admin_token):
        return

    print("Getting user token...")
    user_token = get_user_token()
    if not user_token:
        return

    print("Generating 20 past interviews...")
    success_count = 0
    for i in range(20):
        # Generate random days in the past (1 to 60 days ago)
        days_ago = random.randint(1, 60)
        if create_and_update_interview(user_token, admin_token, days_ago):
            success_count += 1
            
    print(f"Done. Successfully created {success_count} interviews.")

if __name__ == "__main__":
    main()
