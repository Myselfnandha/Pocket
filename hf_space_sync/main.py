"""
Pocket Vault Hugging Face Space - Free Private Cloud Storage Backend
Deploy this file to your free private Hugging Face Space (Docker or Blank template).
Zero hosting cost, AES-256 encrypted storage, fast sync.
"""

import os
import time
import json
import hashlib
from typing import Optional
from fastapi import FastAPI, Header, HTTPException, status
from pydantic import BaseModel

app = FastAPI(title="Pocket Vault Sync Hub", version="1.0.0")

# Space Secret configured in Hugging Face Space Settings -> Repository Secrets
API_SECRET_KEY = os.environ.get("POCKET_API_KEY", "")
DATA_DIR = "/data" if os.path.exists("/data") else "."
STORAGE_FILE = os.path.join(DATA_DIR, "pocket_vault_backup.enc.json")


class PushPayload(BaseModel):
    data: str
    checksum: Optional[str] = None
    deviceId: Optional[str] = "PocketDevice"
    appVersion: Optional[str] = "1.5.18"


def verify_auth(authorization: Optional[str]):
    if not API_SECRET_KEY:
        # If no secret configured in Space, allow connection with warning
        return
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header"
        )
    token = authorization.replace("Bearer ", "").strip()
    if token != API_SECRET_KEY:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid Secret API Key"
        )


@app.get("/")
@app.get("/health")
def health_check():
    has_backup = os.path.exists(STORAGE_FILE)
    last_modified = int(os.path.getmtime(STORAGE_FILE) * 1000) if has_backup else None
    return {
        "status": "healthy",
        "service": "Pocket Free Private Vault Hub",
        "version": "1.0.0",
        "has_backup": has_backup,
        "last_sync_timestamp": last_modified,
    }


@app.post("/sync/push")
def push_vault(payload: PushPayload, authorization: Optional[str] = Header(None)):
    verify_auth(authorization)
    
    # Calculate checksum to ensure integrity
    calc_checksum = hashlib.sha256(payload.data.encode('utf-8')).hexdigest()
    if payload.checksum and payload.checksum != calc_checksum:
        raise HTTPException(status_code=400, detail="Checksum mismatch")

    now_ms = int(time.time() * 1000)
    record = {
        "data": payload.data,
        "checksum": calc_checksum,
        "timestamp": now_ms,
        "deviceId": payload.deviceId,
        "appVersion": payload.appVersion
    }

    temp_file = f"{STORAGE_FILE}.tmp"
    with open(temp_file, "w", encoding="utf-8") as f:
        json.dump(record, f)
    os.replace(temp_file, STORAGE_FILE)

    return {
        "success": True,
        "message": "Vault successfully committed to Hugging Face Space",
        "timestamp": now_ms,
        "checksum": calc_checksum
    }


@app.get("/sync/pull")
def pull_vault(authorization: Optional[str] = Header(None)):
    verify_auth(authorization)

    if not os.path.exists(STORAGE_FILE):
        raise HTTPException(status_code=404, detail="No vault backup found on this Space")

    with open(STORAGE_FILE, "r", encoding="utf-8") as f:
        record = json.load(f)

    return {
        "success": True,
        "data": record["data"],
        "timestamp": record.get("timestamp", 0),
        "checksum": record.get("checksum", ""),
        "deviceId": record.get("deviceId", "Unknown"),
    }
