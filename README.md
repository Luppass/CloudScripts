# Cloud Automation Scripts

This repository contains a collection of scripts for automating operations and management tasks across **multiple cloud platforms**.  
The goal is to provide reusable tools that improve efficiency, consistency, and governance in hybrid and multicloud environments.

---

## 🌍 Scope

The scripts in this repository may cover tasks related to:

- **Resource provisioning and scaling**  
- **Cost optimization and monitoring**  
- **Identity and access management**  
- **Security and compliance checks**  
- **Backup, recovery, and lifecycle management**  
- **Operational automation** (start/stop, scheduling, tagging, etc.)  

---

## 📂 Structure

Scripts are grouped by cloud provider and/or functionality:

- `Azure/`  
- `AWS/`  
- `GCP/`  
- `Common/` (scripts usable across providers)  

Each folder includes its own `README.md` with specific details.

---

## ⚙️ Requirements

Depending on the script, you may need:

- **PowerShell Core** (`pwsh`) or other compatible shell  
- The respective **CLI tools** (e.g., Azure CLI, AWS CLI, gcloud CLI)  
- Cloud provider SDKs or modules (e.g., Az PowerShell, AWS Tools for PowerShell, Google Cloud SDK)  
- Access to the corresponding cloud subscription/account with sufficient permissions  
