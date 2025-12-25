#!/bin/bash

# Fish of Fortune - Game Flow Automation Script
# This script performs specific actions in the game and takes screenshots

# Configuration
DEVICE_IP="10.10.0.114:5555"
PACKAGE_NAME="com.whalo.games.fishoffortune"
SCREENSHOT_DIR="/Users/user/Desktop/fof_screenshots"

# Screen resolution: 1080x2392
# Button coordinates (adjust these if clicks don't land correctly)
GUEST_BUTTON_X=540      # Center X
GUEST_BUTTON_Y=2160     # Y position for Guest button

# X button coordinates for popups (top-right corner)
POPUP_X_BUTTON_X=1051   # Right side
POPUP_X_BUTTON_Y=645    # Upper area

# How many popups to close
MAX_POPUPS=5

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Screenshot counter
screenshot_num=1

# Function to print status messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_action() {
    echo -e "${CYAN}[ACTION]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to take a screenshot with a descriptive name
take_screenshot() {
    local description="$1"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local filename=$(printf "%02d_%s_%s.png" "$screenshot_num" "$description" "$timestamp")
    local device_path="/sdcard/screenshot_temp.png"
    local local_path="${SCREENSHOT_DIR}/${filename}"
    
    log_info "Taking screenshot #$screenshot_num: $description"
    
    # Take screenshot on device
    adb -s "$DEVICE_IP" shell screencap -p "$device_path"
    
    if [ $? -eq 0 ]; then
        # Pull screenshot to computer
        adb -s "$DEVICE_IP" pull "$device_path" "$local_path" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            # Clean up device screenshot
            adb -s "$DEVICE_IP" shell rm "$device_path"
            log_success "Screenshot saved: $filename"
            ((screenshot_num++))
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

# Function to tap at specific coordinates
tap_screen() {
    local x=$1
    local y=$2
    local description="$3"
    
    log_action "Tapping at ($x, $y) - $description"
    adb -s "$DEVICE_IP" shell input tap "$x" "$y"
    sleep 0.5
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
    
    # Swipe up to unlock
    adb -s "$DEVICE_IP" shell input swipe 540 1800 540 800 300
    sleep 1
    
    log_success "Phone is awake!"
}

# Function to launch the game
launch_game() {
    log_info "Launching Fish of Fortune..."
    adb -s "$DEVICE_IP" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log_success "Game launch command sent!"
        return 0
    else
        log_error "Failed to launch the game!"
        return 1
    fi
}

# Main automation flow
run_game_flow() {
    echo ""
    echo "=========================================="
    echo "  Fish of Fortune - Game Flow Automation "
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
    
    # ============================================
    # STEP 1: Wait 10 seconds and take first screenshot
    # ============================================
    log_info "Waiting 10 seconds for game to load..."
    sleep 10
    take_screenshot "game_loaded"
    
    # ============================================
    # STEP 2: Click Guest button
    # ============================================
    sleep 1
    tap_screen $GUEST_BUTTON_X $GUEST_BUTTON_Y "Guest button"
    
    # ============================================
    # STEP 3: Wait 1 second and take screenshot
    # ============================================
    log_info "Waiting 1 second after clicking Guest..."
    sleep 1
    take_screenshot "after_guest_click"
    
    # ============================================
    # STEP 4: Wait 4 seconds and take screenshot
    # ============================================
    log_info "Waiting 4 seconds..."
    sleep 4
    take_screenshot "game_main_screen"
    
    # ============================================
    # STEP 5: Close popups by clicking X
    # ============================================
    log_info "Looking for popups to close..."
    
    for ((i=1; i<=$MAX_POPUPS; i++)); do
        log_info "Attempting to close popup #$i..."
        
        # Click X button
        tap_screen $POPUP_X_BUTTON_X $POPUP_X_BUTTON_Y "Popup X button"
        
        # Wait 1 second for popup to close
        log_info "Waiting 1 second..."
        sleep 1
        
        # Take screenshot
        take_screenshot "after_popup_${i}_closed"
    done
    
    echo ""
    echo "=========================================="
    log_success "Game flow automation complete!"
    log_info "Total screenshots taken: $((screenshot_num - 1))"
    log_info "Screenshots saved to: $SCREENSHOT_DIR"
    echo "=========================================="
    echo ""
    log_warning "NOTE: If buttons weren't clicked correctly, you may need to"
    log_warning "adjust the coordinates in this script. Edit these values:"
    echo "  GUEST_BUTTON_X=$GUEST_BUTTON_X"
    echo "  GUEST_BUTTON_Y=$GUEST_BUTTON_Y"
    echo "  POPUP_X_BUTTON_X=$POPUP_X_BUTTON_X"
    echo "  POPUP_X_BUTTON_Y=$POPUP_X_BUTTON_Y"
    echo ""
}

# Run the automation
run_game_flow
