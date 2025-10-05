# Odoo Service Manager Scripts

This repository contains two management scripts for Odoo on Windows and Linux. Both scripts provide the same functionality and now include
improved service detection, safer process handling, PostgreSQL coordination, and a small interactive menu.

Key capabilities:
- Detect and gracefully stop Odoo processes using port **8069**
- Stop either only Odoo or both Odoo and PostgreSQL
- Start PostgreSQL first (if needed), then start Odoo
- Check current Odoo status (processes and services)
- Auto-elevate (PowerShell script) or restart with sudo (shell script)
- Open PowerShell 7+ download page (PowerShell script)

---

## Files

1. `odoo-control.ps1` — PowerShell script (Windows)
2. `odoo-control.sh` — Shell script (Linux/macOS)

Both scripts are interactive and present the following menu options:

- Stop Odoo only (leave PostgreSQL running)
- Stop Odoo + PostgreSQL (stop database too)
- Start Odoo service (will start PostgreSQL first if required)
- Check Odoo status (shows processes and registered services)
- (PowerShell only) Open PowerShell 7+ download page
- Exit

---

## Usage (Windows — PowerShell)

1. Run PowerShell as Administrator (the script will auto-elevate when needed).
2. Open the folder that contains `odoo-control.ps1`.
3. Run the script:

   ```powershell
   .\odoo-control.ps1
   ```

4. Choose one of the numbered menu options. Notes:

   - Option 1 stops Odoo only (recommended for normal use).
   - Option 2 stops both Odoo and PostgreSQL; use this only when you intentionally want to stop the database.
   - Option 3 will ensure PostgreSQL is running, then start Odoo.
   - Option 5 opens the Microsoft docs page for installing PowerShell 7+.

---

## Usage (Linux/macOS — Shell)

1. Make the script executable (if not already):

   ```bash
   chmod +x odoo-control.sh
   ```

2. Run the script with root privileges. The script will re-run itself with sudo if needed:

   ```bash
   ./odoo-control.sh
   ```

3. Choose a menu option. Notes:

   - Option 1 stops Odoo only (recommended).
   - Option 2 stops both Odoo and PostgreSQL.
   - Option 3 starts PostgreSQL (if needed) and then Odoo.

---

## Important Notes & Safety

- Stopping PostgreSQL will make Odoo unavailable until the database is started again. Only stop PostgreSQL if you understand the consequences.
- Both scripts try to stop only relevant Odoo processes and will avoid killing system processes (e.g. "System Idle" or PID 0/4).
- Modify hardcoded paths in the scripts to match your installation if your Odoo or Python are installed in non-standard locations.

---

## Troubleshooting / Useful Commands

**Windows:**

```powershell
# Show which process owns port 8069
netstat -ano | findstr :8069
# Get process info by PID
Get-Process -Id <PID> | Select-Object Id, ProcessName, Path
```

**Linux/macOS:**

```bash
# Show which process owns port 8069
sudo lsof -i :8069
# Check a process command line
ps -p <PID> -o args=
```

---

If you'd like to add automatic Windows service creation for Odoo or support additional distributions for the shell script, open an issue or submit a pull request.
