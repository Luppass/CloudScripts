# Azure Cloud Automation Scripts

This repository contains a collection of scripts for automating operations and management tasks in **Microsoft Azure**.  
They are intended to support administrators, developers, and DevOps engineers in improving efficiency, governance, and consistency across cloud environments.

---

## 📂 Structure

Scripts are organized by category or service area (e.g., compute, storage, networking, identity).  
Each folder contains:

- One or more scripts  
- A local `README.md` describing usage and parameters  

---

## ⚙️ Requirements

- **PowerShell Core** (`pwsh`) or compatible shell  
- **Azure CLI**  
- **Az PowerShell module**  
- Access to an **Azure subscription** with sufficient permissions  

---

## 🔑 Authentication

Supported authentication methods may vary by script:  

- **Managed Identity** (recommended for automation)  
- **Service Principal** (with client secret or certificate)  
- **Interactive login** (for testing and local use)  
