# Pocket Vault Free Cloud Storage (Hugging Face Space)

Deploy your own 100% free, private cloud backup and auto-sync server in under 1 minute using Hugging Face Spaces.

### 🚀 1-Minute Setup Guide

1. **Create Free Space on Hugging Face**:
   - Go to [https://huggingface.co/new-space](https://huggingface.co/new-space)
   - Space Name: `pocket-sync` (or any name you prefer)
   - License: `MIT`
   - Space SDK: **Docker** (Blank)
   - Privacy: **Private** 🔒 (Recommended)

2. **Upload Files**:
   - Upload the 3 files in this directory:
     - `Dockerfile`
     - `requirements.txt`
     - `main.py`

3. **Set Security API Key (Optional but Recommended)**:
   - In your Space, navigate to **Settings** -> **Variables and secrets** -> **New secret**
   - Key: `POCKET_API_KEY`
   - Value: Any custom secret passphrase (e.g. `my-pocket-secret-12345`)

4. **Connect Pocket**:
   - Open Pocket -> **Settings** -> **Data & Cloud Sync** -> **Hugging Face Space Storage Hub**
   - Space URL: `https://<your-username>-pocket-sync.hf.space`
   - Secret Key: `my-pocket-secret-12345`
   - Tap **Test Connection** -> **Enable Auto-Sync**!
