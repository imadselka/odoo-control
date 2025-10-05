# Odoo Service Manager Scripts

This repository contains two scripts to manage Odoo services running on Windows or Linux. The scripts help you:

1. Identify and stop the service running on port **8069**.
2. Disable its auto-run (auto-start on boot).
3. Restart Odoo manually when needed.

---

## 🧩 Files

### **1. `odoo_service_manager.ps1` (PowerShell)**

This script allows you to:

* **Option 1:** Stop Odoo service and disable auto-start.
* **Option 2:** Start Odoo service manually.

#### **Usage (Windows)**

1. Right-click PowerShell → Run as Administrator.
2. Navigate to the folder containing the script:

   ```powershell
   cd "D:\Odoo Scripts"
   ```
3. Run the script:

   ```powershell
   .\odoo_service_manager.ps1
   ```
4. Choose an option:

   * `1` → Stop Odoo service and disable auto-run.
   * `2` → Start Odoo service manually.

---

### **2. `odoo_service_manager.sh` (Linux)**

This script performs the same operations on Linux systems.

#### **Usage (Linux)**

1. Open your terminal.
2. Give execution permission:

   ```bash
   chmod +x odoo_service_manager.sh
   ```
3. Run the script:

   ```bash
   ./odoo_service_manager.sh
   ```
4. Choose an option:

   * `1` → Stop Odoo process and disable auto-start.
   * `2` → Start Odoo service manually. 

---

## ⚙️ Notes

* Make sure to run the scripts as **administrator/root**.
* Default Odoo port: **8069**
* You can customize the Odoo executable path in the script.

---

## 💡 Example

**To check what’s using port 8069 manually:**

* **Windows:**

  ```powershell
  netstat -ano | findstr :8069
  ```
* **Linux:**

  ```bash
  sudo lsof -i :8069
  ```

This helps confirm which process (PID) is blocking Odoo before running the script.
