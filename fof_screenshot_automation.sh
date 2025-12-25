#!/bin/bash

# Fish of Fortune Screenshot Automation Script
# This script wakes the phone, launches the game, and takes screenshots

# Configuration
DEVICE_IP="10.10.0.114:5555"
PACKAGE_NAME="com.whalo.games.fishoffortune"
SCREENSHOT_DIR="/Users/user/Desktop/fof_screenshots"
SCREENSHOT_COUNT=5          # Number of screenshots to take
SCREENSHOT_INTERVAL=10      # Seconds between screenshots
GAME_LOAD_WAIT=15           # Seconds to wait for game to load

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print status messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if device is connected
check_device_connection() {
    log_info "Checking device connection..."
    if adb -s "$DEVICE_IP" get-state &> /dev/null; then
        log_success "Device is connected!"
        return 0
    else
        log_error "Device not connected. Attempting to connect..."
        adb connect "$DEVICE_IP"
        sleep 2
        if adb -s "$DEVICE_IP" get-state &> /dev/null; then
            log_success "Successfully connected to device!"
            return 0
        else
            log_error "Failed to connect to device at $DEVICE_IP"
            return 1
        fi
    fi
}

# Function to wake up the phone
wake_phone() {
    log_info "Waking up the phone..."
    adb -s "$DEVICE_IP" shell input keyevent KEYCODE_WAKEUP
    sleep 1
    
    # Also unlock the screen by swiping up (in case there's a lock screen)
    adb -s "$DEVICE_IP" shell input swipe 540 1800 540 800 300
    sleep 1
    
    log_success "Phone should now be awake!"
}

# Function to launch the game
launch_game() {
    log_info "Launching Fish of Fortune..."
    adb -s "$DEVICE_IP" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1
    
    if [ $? -eq 0 ]; then
        log_success "Game launch command sent!"
        log_info "Waiting $GAME_LOAD_WAIT seconds for game to load..."
        sleep "$GAME_LOAD_WAIT"
    else
        log_error "Failed to launch the game!"
        return 1
    fi
}

# Function to take a screenshot
take_screenshot() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local filename="fof_screenshot_${timestamp}.png"
    local device_path="/sdcard/screenshot_temp.png"
    local local_path="${SCREENSHOT_DIR}/${filename}"
    
    log_info "Taking screenshot..."
    
    # Take screenshot on device
    adb -s "$DEVICE_IP" shell screencap -p "$device_path"
    
    if [ $? -eq 0 ]; then
        # Pull screenshot to computer
        adb -s "$DEVICE_IP" pull "$device_path" "$local_path" &> /dev/null
        
        if [ $? -eq 0 ]; then
            # Clean up device screenshot
            adb -s "$DEVICE_IP" shell rm "$device_path"
            log_success "Screenshot saved: $filename"
            return 0
        else
            log_error "Failed to pull screenshot from device"
            return 1
        fi
    else
        log_error "Failed to capture screenshot on device"
        return 1
    fi
}

# Function to run the full automation
run_automation() {
    echo ""
    echo "=========================================="
    echo "  Fish of Fortune Screenshot Automation  "
    echo "=========================================="
    echo ""
    
    # Create screenshot directory if it doesn't exist
    mkdir -p "$SCREENSHOT_DIR"
    
    # Check device connection
    if ! check_device_connection; then
        exit 1
    fi
    
    # Wake up the phone
    wake_phone
    
    # Launch the game
    if ! launch_game; then
        exit 1
    fi
    
    # Take screenshots
    log_info "Starting screenshot capture session..."
    echo ""
    
    successful_screenshots=0
    for ((i=1; i<=$SCREENSHOT_COUNT; i++)); do
        log_info "Capturing screenshot $i of $SCREENSHOT_COUNT..."
        if take_screenshot; then
            ((successful_screenshots++))
        fi
        
        # Wait between screenshots (except for the last one)
        if [ $i -lt $SCREENSHOT_COUNT ]; then
            log_info "Waiting $SCREENSHOT_INTERVAL seconds before next screenshot..."
            sleep "$SCREENSHOT_INTERVAL"
        fi
    done
    
    echo ""
    echo "=========================================="
    log_success "Automation complete!"
    log_info "Screenshots captured: $successful_screenshots / $SCREENSHOT_COUNT"
    log_info "Screenshots saved to: $SCREENSHOT_DIR"
    echo "=========================================="
}

# Parse command line arguments
while getopts "c:i:w:h" opt; do
    case $opt in
        c)
            SCREENSHOT_COUNT=$OPTARG
            ;;
        i)
            SCREENSHOT_INTERVAL=$OPTARG
            ;;
        w)
            GAME_LOAD_WAIT=$OPTARG
            ;;
        h)
            echo "Usage: $0 [-c count] [-i interval] [-w wait_time]"
            echo ""
            echo "Options:"
            echo "  -c COUNT     Number of screenshots to take (default: 5)"
            echo "  -i INTERVAL  Seconds between screenshots (default: 10)"
            echo "  -w WAIT      Seconds to wait for game to load (default: 15)"
            echo "  -h           Show this help message"
            echo ""
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Run the automation
run_automation
