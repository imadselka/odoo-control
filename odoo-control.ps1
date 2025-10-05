# ===============================
# Odoo Control Script (Windows)
# Auto-Run as Administrator
# ===============================

# --- Auto Elevate Script to Administrator ---
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $IsAdmin) {
    Write-Host "🔒 Restarting PowerShell as Administrator..." -ForegroundColor Yellow
    $psExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
    Start-Process $psExe -Verb RunAs -ArgumentList ('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    exit
}

# --- Script starts here after elevation ---

function Show-Menu {
    Write-Host ""
    Write-Host "===================================" -ForegroundColor Cyan
    Write-Host "   ODOO SERVICE CONTROLLER        " -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    Write-Host "1 - Stop Odoo only (keep PostgreSQL running)"
    Write-Host "2 - Stop Odoo + PostgreSQL (stop everything)"
    Write-Host "3 - Start Odoo service (auto-starts PostgreSQL)"
    Write-Host "4 - Check Odoo status"
    Write-Host "5 - Download PowerShell 7+"
    Write-Host "6 - Exit"
    Write-Host "===================================" -ForegroundColor Cyan
}

function Stop-OdooService {
    param(
        [bool]$IncludePostgreSQL = $false
    )
    
    Write-Host "`n[INFO] Checking port 8069..." -ForegroundColor Yellow
    
    # Check what's using port 8069
    $connections = Get-NetTCPConnection -LocalPort 8069 -ErrorAction SilentlyContinue
    if ($connections) {
        # Get unique process IDs and exclude system processes (PID 0 and 4)
        $processIds = $connections | Select-Object -ExpandProperty OwningProcess -Unique | Where-Object { $_ -gt 4 }
        
        if ($processIds) {
            foreach ($processId in $processIds) {
                try {
                    $proc = Get-Process -Id $processId -ErrorAction Stop
                    Write-Host "Found process on port 8069 - PID: $processId" -ForegroundColor White
                    Write-Host "Process Name: $($proc.ProcessName)" -ForegroundColor White
                    Write-Host "Path: $($proc.Path)" -ForegroundColor Gray
                    
                    Write-Host "`nStopping process..." -ForegroundColor Yellow
                    Stop-Process -Id $processId -Force -ErrorAction Stop
                    Start-Sleep -Seconds 2
                    Write-Host "✅ Process stopped successfully." -ForegroundColor Green
                } catch {
                    Write-Host "❌ Error stopping process: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "✓ Only system processes found on port 8069." -ForegroundColor Green
        }
    } else {
        Write-Host "✓ No process found on port 8069." -ForegroundColor Green
    }

    # Check for Odoo Windows Services
    Write-Host "`n[INFO] Checking for Odoo Windows Service..." -ForegroundColor Yellow
    
    if ($IncludePostgreSQL) {
        # Stop both Odoo and PostgreSQL
        $services = Get-Service -ErrorAction SilentlyContinue | Where-Object { 
            $_.Name -like "*odoo*" -or $_.DisplayName -like "*Odoo*" -or 
            $_.Name -like "*postgres*" -or $_.DisplayName -like "*PostgreSQL*"
        }
    } else {
        # Stop only Odoo, exclude PostgreSQL
        $services = Get-Service -ErrorAction SilentlyContinue | Where-Object { 
            ($_.Name -like "*odoo*" -or $_.DisplayName -like "*Odoo*") -and 
            ($_.Name -notlike "*postgres*" -and $_.DisplayName -notlike "*PostgreSQL*")
        }
    }
    
    if ($services) {
        foreach ($s in $services) {
            Write-Host "Found service: $($s.Name) - $($s.DisplayName) [Status: $($s.Status)]" -ForegroundColor White
            
            if ($s.Status -eq 'Running') {
                Write-Host "  Stopping service..." -ForegroundColor Yellow
                Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 1
            }
            
            Write-Host "  Disabling auto-start..." -ForegroundColor Yellow
            Set-Service -Name $s.Name -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host "  ✅ Service stopped and disabled" -ForegroundColor Green
        }
    } else {
        Write-Host "✓ No Odoo-related service found." -ForegroundColor Green
    }

    if ($IncludePostgreSQL) {
        Write-Host "`n✅ All Odoo and PostgreSQL services stopped and auto-run disabled." -ForegroundColor Green
    } else {
        Write-Host "`n✅ All Odoo services stopped and auto-run disabled." -ForegroundColor Green
    }
}

function Start-OdooService {
    Write-Host "`n[INFO] Starting Odoo service..." -ForegroundColor Yellow
    
    # First, check if already running
    $conn = Get-NetTCPConnection -LocalPort 8069 -ErrorAction SilentlyContinue
    if ($conn) {
        Write-Host "⚠️  Odoo is already running on port 8069!" -ForegroundColor Yellow
        return
    }
    
    # Step 1: Ensure PostgreSQL is running first
    Write-Host "`n[STEP 1] Checking PostgreSQL status..." -ForegroundColor Cyan
    $pgServices = Get-Service -ErrorAction SilentlyContinue | Where-Object { 
        $_.Name -like "*postgres*" -or $_.DisplayName -like "*PostgreSQL*"
    }
    
    if ($pgServices) {
        $allRunning = $true
        foreach ($pgService in $pgServices) {
            if ($pgService.Status -ne 'Running') {
                $allRunning = $false
                Write-Host "  PostgreSQL service '$($pgService.Name)' is not running. Starting..." -ForegroundColor Yellow
                
                Set-Service -Name $pgService.Name -StartupType Automatic -ErrorAction SilentlyContinue
                Start-Service -Name $pgService.Name -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 3
                
                $status = (Get-Service -Name $pgService.Name).Status
                if ($status -eq 'Running') {
                    Write-Host "  ✅ PostgreSQL started successfully" -ForegroundColor Green
                } else {
                    Write-Host "  ❌ Failed to start PostgreSQL. Odoo may not work properly!" -ForegroundColor Red
                }
            } else {
                Write-Host "  ✅ PostgreSQL is already running" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "  ⚠️  No PostgreSQL service found. Odoo requires PostgreSQL to run!" -ForegroundColor Yellow
    }
    
    # Step 2: Start Odoo
    Write-Host "`n[STEP 2] Starting Odoo..." -ForegroundColor Cyan
    
    # Try to find and start Odoo service
    $services = Get-Service -ErrorAction SilentlyContinue | Where-Object { 
        $_.Name -like "*odoo*" -or $_.DisplayName -like "*Odoo*" 
    }
    
    if ($services) {
        foreach ($s in $services) {
            Write-Host "Starting service: $($s.Name) - $($s.DisplayName)" -ForegroundColor White
            
            Set-Service -Name $s.Name -StartupType Automatic -ErrorAction SilentlyContinue
            Start-Service -Name $s.Name -ErrorAction SilentlyContinue
            
            Start-Sleep -Seconds 3
            
            $status = (Get-Service -Name $s.Name).Status
            if ($status -eq 'Running') {
                Write-Host "  ✅ Service started successfully and is running" -ForegroundColor Green
                
                # Verify port
                Start-Sleep -Seconds 2
                $checkPort = Get-NetTCPConnection -LocalPort 8069 -ErrorAction SilentlyContinue
                if ($checkPort) {
                    Write-Host "  ✅ Port 8069 is active" -ForegroundColor Green
                } else {
                    Write-Host "  ⚠️  Service running but port 8069 not yet active (may still be starting)" -ForegroundColor Yellow
                }
            } else {
                Write-Host "  ❌ Service failed to start. Status: $status" -ForegroundColor Red
            }
        }
    } else {
        # No service found, try manual start
        Write-Host "⚠️  Odoo service not found. Attempting manual start..." -ForegroundColor Yellow
        
        $odooPath = "D:\Odoo 12.0\python\python.exe"
        $odooScript = "D:\Odoo 12.0\server\odoo-bin"
        
        if ((Test-Path $odooPath) -and (Test-Path $odooScript)) {
            Write-Host "Launching: $odooPath $odooScript" -ForegroundColor White
            
            try {
                Start-Process $odooPath -ArgumentList "`"$odooScript`"" -WorkingDirectory "D:\Odoo 12.0\server" -ErrorAction Stop
                
                Write-Host "Waiting for Odoo to start..." -ForegroundColor Yellow
                Start-Sleep -Seconds 5
                
                $checkPort = Get-NetTCPConnection -LocalPort 8069 -ErrorAction SilentlyContinue
                if ($checkPort) {
                    Write-Host "✅ Odoo launched successfully and port 8069 is active." -ForegroundColor Green
                } else {
                    Write-Host "⚠️  Odoo process started but port 8069 is not yet active. Check logs if needed." -ForegroundColor Yellow
                }
            } catch {
                Write-Host "❌ Error launching Odoo: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "❌ Odoo executable not found at:" -ForegroundColor Red
            Write-Host "   Python: $odooPath (Exists: $(Test-Path $odooPath))" -ForegroundColor Gray
            Write-Host "   Script: $odooScript (Exists: $(Test-Path $odooScript))" -ForegroundColor Gray
            Write-Host "`n💡 Please update the paths in the script to match your Odoo installation." -ForegroundColor Cyan
        }
    }
}

function Start-PostgreSQLService {
    Write-Host "`n[INFO] Starting PostgreSQL service..." -ForegroundColor Yellow
    
    # Find PostgreSQL services
    $services = Get-Service -ErrorAction SilentlyContinue | Where-Object { 
        $_.Name -like "*postgres*" -or $_.DisplayName -like "*PostgreSQL*"
    }
    
    if ($services) {
        foreach ($s in $services) {
            Write-Host "Starting service: $($s.Name) - $($s.DisplayName)" -ForegroundColor White
            
            Set-Service -Name $s.Name -StartupType Automatic -ErrorAction SilentlyContinue
            Start-Service -Name $s.Name -ErrorAction SilentlyContinue
            
            Start-Sleep -Seconds 2
            
            $status = (Get-Service -Name $s.Name).Status
            if ($status -eq 'Running') {
                Write-Host "  ✅ Service started successfully and is running" -ForegroundColor Green
            } else {
                Write-Host "  ❌ Service failed to start. Status: $status" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "❌ No PostgreSQL service found." -ForegroundColor Red
    }
}

function Open-PowerShellDownload {
    Write-Host "`n[INFO] Opening PowerShell 7+ download page..." -ForegroundColor Yellow
    $downloadUrl = "https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5#msi"
    
    Write-Host "Opening: $downloadUrl" -ForegroundColor White
    Start-Process $downloadUrl
    
    Write-Host "`n✅ Download page opened in your default browser." -ForegroundColor Green
    Write-Host "💡 After installing PowerShell 7+, run this script with 'pwsh' instead of 'powershell'" -ForegroundColor Cyan
}

function Check-OdooStatus {
    Write-Host "`n[INFO] Checking Odoo status..." -ForegroundColor Yellow
    
    # Check port 8069
    $connections = Get-NetTCPConnection -LocalPort 8069 -ErrorAction SilentlyContinue
    if ($connections) {
        # Get unique process IDs and exclude system processes
        $processIds = $connections | Select-Object -ExpandProperty OwningProcess -Unique | Where-Object { $_ -gt 4 }
        
        if ($processIds) {
            Write-Host "✅ Odoo is RUNNING" -ForegroundColor Green
            foreach ($processId in $processIds) {
                $proc = Get-Process -Id $processId -ErrorAction SilentlyContinue
                if ($proc) {
                    Write-Host "   Process: $($proc.ProcessName) (PID: $processId)" -ForegroundColor White
                    Write-Host "   Path: $($proc.Path)" -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "❌ Odoo is NOT running (port 8069 is free)" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Odoo is NOT running (port 8069 is free)" -ForegroundColor Red
    }
    
    # Check services
    Write-Host "`n[INFO] Odoo Services:" -ForegroundColor Yellow
    $services = Get-Service -ErrorAction SilentlyContinue | Where-Object { 
        $_.Name -like "*odoo*" -or $_.DisplayName -like "*Odoo*" 
    }
    
    if ($services) {
        foreach ($s in $services) {
            $statusColor = if ($s.Status -eq 'Running') { 'Green' } else { 'Gray' }
            Write-Host "   $($s.Name): $($s.Status) (Startup: $($s.StartType))" -ForegroundColor $statusColor
        }
    } else {
        Write-Host "   No Odoo service found" -ForegroundColor Gray
    }
}

# --- Main Loop ---
do {
    Show-Menu
    $choice = Read-Host "`nChoose an option (1-6)"

    switch ($choice) {
        1 {
            Stop-OdooService -IncludePostgreSQL $false
        }
        2 {
            Stop-OdooService -IncludePostgreSQL $true
        }
        3 {
            Start-OdooService
        }
        4 {
            Check-OdooStatus
        }
        5 {
            Open-PowerShellDownload
        }
        6 {
            Write-Host "`nExiting..." -ForegroundColor Cyan
            break
        }
        Default {
            Write-Host "`n❌ Invalid option. Please choose 1-6." -ForegroundColor Red
        }
    }
    
    if ($choice -ne 6) {
        Write-Host "`nPress any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    
} while ($choice -ne 6)
