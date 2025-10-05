#!/bin/bash
# ===============================
# Odoo Control Script (Linux/macOS)
# ===============================

# Check if running with sudo/root
if [ "$EUID" -ne 0 ]; then
    echo "🔒 This script requires root privileges. Restarting with sudo..."
    sudo bash "$0" "$@"
    exit $?
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

show_menu() {
    echo ""
    echo -e "${CYAN}===================================${NC}"
    echo -e "${CYAN}   ODOO SERVICE CONTROLLER        ${NC}"
    echo -e "${CYAN}===================================${NC}"
    echo "1 - Stop Odoo only (keep PostgreSQL running)"
    echo "2 - Stop Odoo + PostgreSQL (stop everything)"
    echo "3 - Start Odoo service (auto-starts PostgreSQL)"
    echo "4 - Check Odoo status"
    echo "5 - Exit"
    echo -e "${CYAN}===================================${NC}"
}

stop_odoo() {
    local include_postgresql=$1
    
    echo -e "\n${YELLOW}[INFO] Checking port 8069...${NC}"
    
    # Get all PIDs using port 8069
    PIDS=$(lsof -t -i:8069 2>/dev/null)
    
    if [ -n "$PIDS" ]; then
        for PID in $PIDS; do
            # Get process info
            PROC_NAME=$(ps -p $PID -o comm= 2>/dev/null)
            PROC_CMD=$(ps -p $PID -o args= 2>/dev/null)
            
            echo -e "${NC}Found process on port 8069 - PID: $PID${NC}"
            echo -e "${NC}Process Name: $PROC_NAME${NC}"
            echo -e "${GRAY}Command: $PROC_CMD${NC}"
            
            echo -e "\n${YELLOW}Stopping process...${NC}"
            kill -15 $PID 2>/dev/null || kill -9 $PID 2>/dev/null
            sleep 2
            
            if ! ps -p $PID > /dev/null 2>&1; then
                echo -e "${GREEN}✅ Process stopped successfully.${NC}"
            else
                echo -e "${RED}❌ Failed to stop process.${NC}"
            fi
        done
    else
        echo -e "${GREEN}✓ No process found on port 8069.${NC}"
    fi

    # Check for Odoo systemd services
    echo -e "\n${YELLOW}[INFO] Checking for Odoo systemd service...${NC}"
    
    if [ "$include_postgresql" = "true" ]; then
        # Stop both Odoo and PostgreSQL
        SERVICES=$(systemctl list-units --full --all --no-pager 2>/dev/null | grep -iE "odoo|postgres" | awk '{print $1}')
    else
        # Stop only Odoo, exclude PostgreSQL
        SERVICES=$(systemctl list-units --full --all --no-pager 2>/dev/null | grep -i odoo | grep -v postgres | awk '{print $1}')
    fi
    
    if [ -n "$SERVICES" ]; then
        for SERVICE in $SERVICES; do
            SERVICE_NAME=$(echo $SERVICE | sed 's/.service$//')
            STATUS=$(systemctl is-active $SERVICE_NAME 2>/dev/null)
            
            echo -e "${NC}Found service: $SERVICE_NAME [Status: $STATUS]${NC}"
            
            if [ "$STATUS" = "active" ]; then
                echo -e "  ${YELLOW}Stopping service...${NC}"
                systemctl stop $SERVICE_NAME
                sleep 1
            fi
            
            echo -e "  ${YELLOW}Disabling auto-start...${NC}"
            systemctl disable $SERVICE_NAME >/dev/null 2>&1
            echo -e "  ${GREEN}✅ Service stopped and disabled${NC}"
        done
    else
        echo -e "${GREEN}✓ No Odoo-related service found.${NC}"
    fi

    if [ "$include_postgresql" = "true" ]; then
        echo -e "\n${GREEN}✅ All Odoo and PostgreSQL services stopped and auto-run disabled.${NC}"
    else
        echo -e "\n${GREEN}✅ All Odoo services stopped and auto-run disabled.${NC}"
    fi
}

start_odoo() {
    echo -e "\n${YELLOW}[INFO] Starting Odoo service...${NC}"
    
    # First, check if already running
    if lsof -i:8069 >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Odoo is already running on port 8069!${NC}"
        return
    fi
    
    # Step 1: Ensure PostgreSQL is running first
    echo -e "\n${CYAN}[STEP 1] Checking PostgreSQL status...${NC}"
    PG_SERVICES=$(systemctl list-units --full --all --no-pager 2>/dev/null | grep -i postgres | awk '{print $1}')
    
    if [ -n "$PG_SERVICES" ]; then
        for PG_SERVICE in $PG_SERVICES; do
            PG_SERVICE_NAME=$(echo $PG_SERVICE | sed 's/.service$//')
            PG_STATUS=$(systemctl is-active $PG_SERVICE_NAME 2>/dev/null)
            
            if [ "$PG_STATUS" != "active" ]; then
                echo -e "  ${YELLOW}PostgreSQL service '$PG_SERVICE_NAME' is not running. Starting...${NC}"
                
                systemctl enable $PG_SERVICE_NAME >/dev/null 2>&1
                systemctl start $PG_SERVICE_NAME
                sleep 3
                
                PG_STATUS=$(systemctl is-active $PG_SERVICE_NAME 2>/dev/null)
                if [ "$PG_STATUS" = "active" ]; then
                    echo -e "  ${GREEN}✅ PostgreSQL started successfully${NC}"
                else
                    echo -e "  ${RED}❌ Failed to start PostgreSQL. Odoo may not work properly!${NC}"
                fi
            else
                echo -e "  ${GREEN}✅ PostgreSQL is already running${NC}"
            fi
        done
    else
        echo -e "  ${YELLOW}⚠️  No PostgreSQL service found. Odoo requires PostgreSQL to run!${NC}"
    fi
    
    # Step 2: Start Odoo
    echo -e "\n${CYAN}[STEP 2] Starting Odoo...${NC}"
    
    # Try to find and start Odoo systemd service
    SERVICES=$(systemctl list-units --full --all --no-pager 2>/dev/null | grep -i odoo | grep -v postgres | awk '{print $1}')
    
    if [ -n "$SERVICES" ]; then
        for SERVICE in $SERVICES; do
            SERVICE_NAME=$(echo $SERVICE | sed 's/.service$//')
            echo -e "${NC}Starting service: $SERVICE_NAME${NC}"
            
            systemctl enable $SERVICE_NAME >/dev/null 2>&1
            systemctl start $SERVICE_NAME
            
            sleep 3
            
            STATUS=$(systemctl is-active $SERVICE_NAME 2>/dev/null)
            if [ "$STATUS" = "active" ]; then
                echo -e "  ${GREEN}✅ Service started successfully and is running${NC}"
                
                # Verify port
                sleep 2
                if lsof -i:8069 >/dev/null 2>&1; then
                    echo -e "  ${GREEN}✅ Port 8069 is active${NC}"
                else
                    echo -e "  ${YELLOW}⚠️  Service running but port 8069 not yet active (may still be starting)${NC}"
                fi
            else
                echo -e "  ${RED}❌ Service failed to start. Status: $STATUS${NC}"
            fi
        done
    else
        # No service found, try manual start
        echo -e "${YELLOW}⚠️  Odoo service not found. Attempting manual start...${NC}"
        
        # Common Odoo installation paths
        ODOO_PATHS=(
            "/opt/odoo/odoo-bin"
            "/usr/bin/odoo"
            "/usr/local/bin/odoo"
            "~/odoo/odoo-bin"
        )
        
        ODOO_BIN=""
        for PATH_CHECK in "${ODOO_PATHS[@]}"; do
            if [ -f "$PATH_CHECK" ]; then
                ODOO_BIN="$PATH_CHECK"
                break
            fi
        done
        
        if [ -n "$ODOO_BIN" ]; then
            echo -e "${NC}Launching: $ODOO_BIN${NC}"
            
            # Start Odoo in background
            cd "$(dirname "$ODOO_BIN")" || exit
            "$ODOO_BIN" &
            
            echo -e "${YELLOW}Waiting for Odoo to start...${NC}"
            sleep 5
            
            if lsof -i:8069 >/dev/null 2>&1; then
                echo -e "${GREEN}✅ Odoo launched successfully and port 8069 is active.${NC}"
            else
                echo -e "${YELLOW}⚠️  Odoo process started but port 8069 is not yet active. Check logs if needed.${NC}"
            fi
        else
            echo -e "${RED}❌ Odoo executable not found at common locations:${NC}"
            for PATH_CHECK in "${ODOO_PATHS[@]}"; do
                echo -e "${GRAY}   $PATH_CHECK (Exists: $([ -f "$PATH_CHECK" ] && echo "Yes" || echo "No"))${NC}"
            done
            echo -e "\n${CYAN}💡 Please update the paths in the script to match your Odoo installation.${NC}"
        fi
    fi
}

start_postgresql() {
    echo -e "\n${YELLOW}[INFO] Starting PostgreSQL service...${NC}"
    
    # Try to find PostgreSQL systemd service
    SERVICES=$(systemctl list-units --full --all --no-pager 2>/dev/null | grep -i postgres | awk '{print $1}')
    
    if [ -n "$SERVICES" ]; then
        for SERVICE in $SERVICES; do
            SERVICE_NAME=$(echo $SERVICE | sed 's/.service$//')
            echo -e "${NC}Starting service: $SERVICE_NAME${NC}"
            
            systemctl enable $SERVICE_NAME >/dev/null 2>&1
            systemctl start $SERVICE_NAME
            
            sleep 2
            
            STATUS=$(systemctl is-active $SERVICE_NAME 2>/dev/null)
            if [ "$STATUS" = "active" ]; then
                echo -e "  ${GREEN}✅ Service started successfully and is running${NC}"
            else
                echo -e "  ${RED}❌ Service failed to start. Status: $STATUS${NC}"
            fi
        done
    else
        echo -e "${RED}❌ No PostgreSQL service found.${NC}"
    fi
}

check_status() {
    echo -e "\n${YELLOW}[INFO] Checking Odoo status...${NC}"
    
    # Check port 8069
    PIDS=$(lsof -t -i:8069 2>/dev/null)
    
    if [ -n "$PIDS" ]; then
        echo -e "${GREEN}✅ Odoo is RUNNING${NC}"
        for PID in $PIDS; do
            PROC_NAME=$(ps -p $PID -o comm= 2>/dev/null)
            PROC_CMD=$(ps -p $PID -o args= 2>/dev/null)
            echo -e "${NC}   Process: $PROC_NAME (PID: $PID)${NC}"
            echo -e "${GRAY}   Command: $PROC_CMD${NC}"
        done
    else
        echo -e "${RED}❌ Odoo is NOT running (port 8069 is free)${NC}"
    fi
    
    # Check services
    echo -e "\n${YELLOW}[INFO] Odoo Services:${NC}"
    SERVICES=$(systemctl list-units --full --all --no-pager 2>/dev/null | grep -i odoo | awk '{print $1}')
    
    if [ -n "$SERVICES" ]; then
        for SERVICE in $SERVICES; do
            SERVICE_NAME=$(echo $SERVICE | sed 's/.service$//')
            STATUS=$(systemctl is-active $SERVICE_NAME 2>/dev/null)
            STARTUP=$(systemctl is-enabled $SERVICE_NAME 2>/dev/null)
            
            if [ "$STATUS" = "active" ]; then
                echo -e "   ${GREEN}$SERVICE_NAME: $STATUS (Startup: $STARTUP)${NC}"
            else
                echo -e "   ${GRAY}$SERVICE_NAME: $STATUS (Startup: $STARTUP)${NC}"
            fi
        done
    else
        echo -e "${GRAY}   No Odoo service found${NC}"
    fi
}

# Main loop
while true; do
    show_menu
    read -p "Choose an option (1-5): " choice

    case $choice in
        1)
            stop_odoo false
            ;;
        2)
            stop_odoo true
            ;;
        3)
            start_odoo
            ;;
        4)
            check_status
            ;;
        5)
            echo -e "\n${CYAN}Exiting...${NC}"
            exit 0
            ;;
        *)
            echo -e "\n${RED}❌ Invalid option. Please choose 1-5.${NC}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done
