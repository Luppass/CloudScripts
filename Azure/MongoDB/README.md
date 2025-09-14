# Azure Cosmos DB Management Scripts

This repository contains two PowerShell scripts to help manage and scale **Azure Cosmos DB (MongoDB API)** resources.  
They use **Managed Identity authentication** and the **Azure CLI**, and include structured logging for traceability.

---

## 📂 Contents

- **`mongoDBaccountRUAutoReduceThroughput.ps1`**  
  Displays (without executing) the **update commands** required to reduce throughput (RU/s) of MongoDB databases or collections.  
  It ensures compliance with minimum and step requirements for both *Manual* and *Autoscale* modes.

- **`mongoDBClusterAutoScale.ps1`**  
  Updates vCore-based Cosmos DB MongoDB clusters filtered by tag.  
  It automatically scales clusters to a new **node tier** and **disk size**.

---

## ⚙️ Requirements

- **PowerShell Core** (`pwsh`)  
- **Azure CLI** (with `cosmosdb-preview` extension)  
- **Az PowerShell module**  
- Access to an **Azure subscription** with appropriate permissions  

Authentication is handled via **Managed Identity**.

---

## 🚀 Usage

### 1. Auto Reduce Throughput Script

Outputs the **commands to reduce throughput** — it does **not** apply changes directly.  

```bash
pwsh ./mongoDBaccountRUAutoReduceThroughput.ps1
