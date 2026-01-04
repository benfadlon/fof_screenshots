#!/bin/bash

# Fish of Fortune - Game Flow Automation Script
# This script performs specific actions in the game and takes screenshots
# Auto-detects when popups are finished by checking pixel color!

# Configuration
DEVICE_IP="00169154P000848"
SCREENSHOT_DIR="/Users/user/Desktop/fof_screenshots"
PACKAGE_NAME="com.whalo.games.fishoffortune"

# Slack Configuration (set SLACK_BOT_TOKEN environment variable)
SLACK_BOT_TOKEN="${SLACK_BOT_TOKEN:-}"
SLACK_CHANNEL_ID="C0A5403G17H"

# Screen resolution: 1080x2392
# Button coordinates
GUEST_BUTTON_X=540      # Center X
GUEST_BUTTON_Y=2160     # Y position for Guest button

# X button coordinates for popups
POPUP_X_BUTTON_X=1066   # Right side
POPUP_X_BUTTON_Y=475    # Upper area

# Pixel to check for popup detection
CHECK_PIXEL_X=965
CHECK_PIXEL_Y=220
# When popups are done, this pixel is yellowish RGB(255, 255, 213) - G > 200
# When popup is present, the pixel is different (usually reddish, G < 100)

# Constant reference colors for button detection (captured from main screen)
# Check 1: (1044, 587)
REFERENCE_COLOR_1="255,255,247"
# Check 2: (1044, 783)
REFERENCE_COLOR_2="255,255,245"
# Check 3: (1044, 968)
REFERENCE_COLOR_3="255,253,235"
# Check 4: (1044, 1176)
REFERENCE_COLOR_4="255,250,205"

# Color at (98, 2260) to detect if re-click is needed (from image.png)
DUPLICATE_CHECK_COLOR="255,253,253"

# Pre-popup check: Color at (320, 420) from game_main_screen
PRE_POPUP_CHECK_COLOR="255,253,47"

# Maximum popups to try (safety limit)
MAX_POPUPS=15

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

# Function to check if popups are finished by checking pixel color
# Returns 0 if popups are done, 1 if popup still present
check_popups_done() {
    local temp_file="/sdcard/pixel_check.png"
    local local_file="/tmp/pixel_check.png"
    
    # Take screenshot
    adb -s "$DEVICE_IP" shell screencap -p "$temp_file" 2>/dev/null
    adb -s "$DEVICE_IP" pull "$temp_file" "$local_file" 2>/dev/null
    adb -s "$DEVICE_IP" shell rm "$temp_file" 2>/dev/null
    
    # Extract pixel color and check if popups are done
    local result=$(python3 << EOF
import subprocess

x = $CHECK_PIXEL_X
y = $CHECK_PIXEL_Y
local_file = "/tmp/pixel_check.png"

# Extract the pixel using sips
subprocess.run(f'sips -c 1 1 --cropOffset {y} {x} "{local_file}" -s format bmp -o /tmp/pixel.bmp 2>/dev/null', shell=True, capture_output=True)

try:
    with open('/tmp/pixel.bmp', 'rb') as f:
        data = f.read()
        b, g, r = data[-3], data[-2], data[-1]
        
        # Check if popups are done: yellowish color means G > 200
        if g > 200:
            print(f"DONE:RGB({r},{g},{b})")
        else:
            print(f"POPUP:RGB({r},{g},{b})")
except Exception as e:
    print(f"ERROR:{e}")
EOF
)
    
    # Parse the result
    local status=$(echo "$result" | cut -d':' -f1)
    local color=$(echo "$result" | cut -d':' -f2)
    
    log_info "Pixel color at ($CHECK_PIXEL_X, $CHECK_PIXEL_Y): $color (status: $status)"
    
    if [ "$status" = "DONE" ]; then
        return 0  # Popups done
    else
        return 1  # Popup still present
    fi
}

# Function to get pixel color at specific coordinates
# Returns: "R,G,B" format
get_pixel_color() {
    local x=$1
    local y=$2
    local temp_file="/sdcard/pixel_check.png"
    local local_file="/tmp/pixel_check.png"
    
    # Take screenshot
    adb -s "$DEVICE_IP" shell screencap -p "$temp_file" 2>/dev/null
    adb -s "$DEVICE_IP" pull "$temp_file" "$local_file" 2>/dev/null
    adb -s "$DEVICE_IP" shell rm "$temp_file" 2>/dev/null
    
    # Extract pixel color
    python3 << EOF
import subprocess

x = $x
y = $y
local_file = "/tmp/pixel_check.png"

subprocess.run(f'sips -c 1 1 --cropOffset {y} {x} "{local_file}" -s format bmp -o /tmp/pixel.bmp 2>/dev/null', shell=True, capture_output=True)

try:
    with open('/tmp/pixel.bmp', 'rb') as f:
        data = f.read()
        b, g, r = data[-3], data[-2], data[-1]
        print(f"{r},{g},{b}")
except:
    print("0,0,0")
EOF
}

# Function to compare two colors (with tolerance)
# Returns 0 if colors match, 1 if different
compare_colors() {
    local color1="$1"
    local color2="$2"
    local tolerance=30  # Allow some variation
    
    local r1=$(echo "$color1" | cut -d',' -f1)
    local g1=$(echo "$color1" | cut -d',' -f2)
    local b1=$(echo "$color1" | cut -d',' -f3)
    
    local r2=$(echo "$color2" | cut -d',' -f1)
    local g2=$(echo "$color2" | cut -d',' -f2)
    local b2=$(echo "$color2" | cut -d',' -f3)
    
    local diff_r=$((r1 - r2))
    local diff_g=$((g1 - g2))
    local diff_b=$((b1 - b2))
    
    # Absolute values
    [ $diff_r -lt 0 ] && diff_r=$((diff_r * -1))
    [ $diff_g -lt 0 ] && diff_g=$((diff_g * -1))
    [ $diff_b -lt 0 ] && diff_b=$((diff_b * -1))
    
    if [ $diff_r -le $tolerance ] && [ $diff_g -le $tolerance ] && [ $diff_b -le $tolerance ]; then
        return 0  # Colors match
    else
        return 1  # Colors different
    fi
}

# Variable to store last screenshot path
LAST_SCREENSHOT_PATH=""

# Function to take a screenshot with a descriptive name
# Also stores the path in LAST_SCREENSHOT_PATH
take_screenshot() {
    local description="$1"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local filename=$(printf "%02d_%s_%s.png" "$screenshot_num" "$description" "$timestamp")
    local device_path="/sdcard/screenshot_temp.png"
    local local_path="${SCREENSHOT_DIR}/${filename}"
    
    log_info "Taking screenshot #$screenshot_num: $description"
    
    adb -s "$DEVICE_IP" shell screencap -p "$device_path"
    
    if [ $? -eq 0 ]; then
        adb -s "$DEVICE_IP" pull "$device_path" "$local_path" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            adb -s "$DEVICE_IP" shell rm "$device_path"
            log_success "Screenshot saved: $filename"
            LAST_SCREENSHOT_PATH="$local_path"
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

# Function to compare two screenshots by checking specific pixel colors
# Returns 0 if screenshots are similar (duplicate), 1 if different
compare_screenshots() {
    local file1="$1"
    local file2="$2"
    
    if [ ! -f "$file1" ] || [ ! -f "$file2" ]; then
        return 1  # Files don't exist, consider different
    fi
    
    # Compare multiple pixels to determine similarity
    local match_count=0
    local check_points=("540,600" "540,800" "540,1000" "540,1200")
    
    for point in "${check_points[@]}"; do
        local x=$(echo "$point" | cut -d',' -f1)
        local y=$(echo "$point" | cut -d',' -f2)
        
        # Get color from file1
        local color1=$(python3 << EOF
import subprocess
subprocess.run('sips -c 1 1 --cropOffset $y $x "$file1" -s format bmp -o /tmp/p1.bmp 2>/dev/null', shell=True, capture_output=True)
try:
    with open('/tmp/p1.bmp', 'rb') as f:
        data = f.read()
        print(f"{data[-3]},{data[-2]},{data[-1]}")
except:
    print("0,0,0")
EOF
)
        
        # Get color from file2
        local color2=$(python3 << EOF
import subprocess
subprocess.run('sips -c 1 1 --cropOffset $y $x "$file2" -s format bmp -o /tmp/p2.bmp 2>/dev/null', shell=True, capture_output=True)
try:
    with open('/tmp/p2.bmp', 'rb') as f:
        data = f.read()
        print(f"{data[-3]},{data[-2]},{data[-1]}")
except:
    print("0,0,0")
EOF
)
        
        # Compare colors with tolerance
        if [ "$color1" = "$color2" ]; then
            ((match_count++))
        fi
    done
    
    # If 3 or more points match, consider it a duplicate
    if [ $match_count -ge 3 ]; then
        return 0  # Similar/duplicate
    else
        return 1  # Different
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
    echo "     (Auto-detects popup completion!)    "
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
    # STEP 4: Wait 9 seconds and take screenshot
    # ============================================
    log_info "Waiting 9 seconds..."
    sleep 9
    take_screenshot "game_main_screen"
    
    # ============================================
    # STEP 4.5: Check pixel at (320, 420) - if matches, click button
    # ============================================
    echo ""
    log_info "Checking pixel at (320, 420) for pre-popup action..."
    local pre_popup_color=$(get_pixel_color 320 420)
    log_info "Current color: RGB($pre_popup_color) vs Reference: RGB($PRE_POPUP_CHECK_COLOR)"
    
    if compare_colors "$pre_popup_color" "$PRE_POPUP_CHECK_COLOR"; then
        log_success "Color matches! Clicking at (582, 2280)..."
        tap_screen 582 2280 "Pre-popup button"
        sleep 1
        take_screenshot "after_pre_popup_click"
    else
        log_warning "Color does not match, skipping pre-popup click"
    fi
    
    # ============================================
    # STEP 5: Close popups (auto-detect when done)
    # ============================================
    log_info "Closing popups (will auto-detect when finished)..."
    echo ""
    
    local popups_closed=0
    
    for ((i=1; i<=$MAX_POPUPS; i++)); do
        log_info "Attempting to close popup #$i..."
        
        # Click X button
        tap_screen $POPUP_X_BUTTON_X $POPUP_X_BUTTON_Y "Popup X button"
        
        # Immediately click second X button position
        adb -s "$DEVICE_IP" shell input tap 1066 330
        
        # Immediately click third position
        adb -s "$DEVICE_IP" shell input tap 500 2200
        
        # Wait for popup to close
        sleep 2
        
        # Take screenshot
        take_screenshot "after_popup_${i}_closed"
        
        # Check if popups are done
        if check_popups_done; then
            log_success "🎉 All popups closed! Detected yellowish pixel at ($CHECK_PIXEL_X, $CHECK_PIXEL_Y)"
            popups_closed=$i
            break
        else
            log_info "Popup still detected, continuing..."
            ((popups_closed++))
        fi
        
        echo ""
    done
    
    # ============================================
    # STEP 6: Click at (710, 200)
    # ============================================
    echo ""
    log_info "Clicking at (710, 200)..."
    tap_screen 710 200 "Menu button"
    sleep 1
    
    # ============================================
    # STEP 7: Scroll down 1500 pixels
    # ============================================
    log_info "Scrolling down (1500 pixels)..."
    adb -s "$DEVICE_IP" shell input swipe 540 1000 540 2500 300
    sleep 1
    take_screenshot "after_scroll_down"
    
    # ============================================
    # STEP 8: Scroll up 1806 pixels
    # ============================================
    log_info "Scrolling up (1806 pixels)..."
    adb -s "$DEVICE_IP" shell input swipe 540 2000 540 194 300
    sleep 1
    take_screenshot "after_scroll_up"
    
    # ============================================
    # STEP 9: Click at (535, 2277)
    # ============================================
    log_info "Clicking button at (535, 2277)..."
    tap_screen 535 2277 "Button"
    sleep 1
    
    # ============================================
    # STEP 10: Click at (990, 400), wait 3s, screenshot, click (70, 180)
    # ============================================
    echo ""
    log_info "Clicking at (990, 400)..."
    tap_screen 990 400 "Button"
    sleep 3
    take_screenshot "after_990_400_click"
    
    log_info "Clicking at (70, 180)..."
    tap_screen 70 180 "Button"
    
    # Wait 2 seconds before checking color
    sleep 2
    
    # ============================================
    # STEP 11: Check color at (1044, 587) and click if matches
    # ============================================
    echo ""
    log_info "Checking color at (1044, 587)..."
    local current_color=$(get_pixel_color 1044 587)
    log_info "Current color: RGB($current_color) vs Reference: RGB($REFERENCE_COLOR_1)"
    
    if compare_colors "$current_color" "$REFERENCE_COLOR_1"; then
        log_success "Color matches! Clicking at (1044, 587)..."
        tap_screen 1044 587 "Matched button"
        sleep 8
        take_screenshot "after_1044_587_click"
        
        log_info "Clicking comeback at (120, 2250)..."
        tap_screen 120 2250 "Comeback button"
        sleep 4
        
        # Check if re-click is needed by checking color at (98, 2260)
        local check_color=$(get_pixel_color 98 2260)
        log_info "Checking duplicate at (98, 2260): RGB($check_color) vs RGB($DUPLICATE_CHECK_COLOR)"
        
        if compare_colors "$check_color" "$DUPLICATE_CHECK_COLOR"; then
            log_warning "Re-click needed! Waiting 6 seconds..."
            sleep 6
            
            log_info "Re-clicking at (1044, 587)..."
            tap_screen 1044 587 "Re-click button"
            sleep 4
            
            log_info "Clicking comeback at (120, 2250)..."
            tap_screen 120 2250 "Comeback button"
            sleep 4
        fi
    else
        log_warning "Color does not match, skipping click"
    fi
    
    # ============================================
    # STEP 12: Check color at (1044, 783) and click if matches
    # ============================================
    echo ""
    log_info "Checking color at (1044, 783)..."
    current_color=$(get_pixel_color 1044 783)
    log_info "Current color: RGB($current_color) vs Reference: RGB($REFERENCE_COLOR_2)"
    
    if compare_colors "$current_color" "$REFERENCE_COLOR_2"; then
        log_success "Color matches! Clicking at (1044, 783)..."
        tap_screen 1044 783 "Matched button"
        sleep 8
        take_screenshot "after_1044_783_click"
        
        log_info "Clicking comeback at (120, 2250)..."
        tap_screen 120 2250 "Comeback button"
        sleep 4
        
        # Check if re-click is needed by checking color at (98, 2260)
        local check_color=$(get_pixel_color 98 2260)
        log_info "Checking duplicate at (98, 2260): RGB($check_color) vs RGB($DUPLICATE_CHECK_COLOR)"
        
        if compare_colors "$check_color" "$DUPLICATE_CHECK_COLOR"; then
            log_warning "Re-click needed! Waiting 6 seconds..."
            sleep 6
            
            log_info "Re-clicking at (1044, 783)..."
            tap_screen 1044 783 "Re-click button"
            sleep 4
            
            log_info "Clicking comeback at (120, 2250)..."
            tap_screen 120 2250 "Comeback button"
            sleep 4
        fi
    else
        log_warning "Color does not match, skipping click"
    fi
    
    # ============================================
    # STEP 13: Check color at (1044, 968) and click if matches
    # ============================================
    echo ""
    log_info "Checking color at (1044, 968)..."
    current_color=$(get_pixel_color 1044 968)
    log_info "Current color: RGB($current_color) vs Reference: RGB($REFERENCE_COLOR_3)"
    
    if compare_colors "$current_color" "$REFERENCE_COLOR_3"; then
        log_success "Color matches! Clicking at (1044, 968)..."
        tap_screen 1044 968 "Matched button"
        sleep 8
        take_screenshot "after_1044_968_click"
        
        log_info "Clicking comeback at (120, 2250)..."
        tap_screen 120 2250 "Comeback button"
        sleep 4
        
        # Check if re-click is needed by checking color at (98, 2260)
        local check_color=$(get_pixel_color 98 2260)
        log_info "Checking duplicate at (98, 2260): RGB($check_color) vs RGB($DUPLICATE_CHECK_COLOR)"
        
        if compare_colors "$check_color" "$DUPLICATE_CHECK_COLOR"; then
            log_warning "Re-click needed! Waiting 6 seconds..."
            sleep 6
            
            log_info "Re-clicking at (1044, 968)..."
            tap_screen 1044 968 "Re-click button"
            sleep 4
            
            log_info "Clicking comeback at (120, 2250)..."
            tap_screen 120 2250 "Comeback button"
            sleep 4
        fi
    else
        log_warning "Color does not match, skipping click"
    fi
    
    # ============================================
    # STEP 14: Check color at (1044, 1176) and click if matches
    # ============================================
    echo ""
    log_info "Checking color at (1044, 1176)..."
    current_color=$(get_pixel_color 1044 1176)
    log_info "Current color: RGB($current_color) vs Reference: RGB($REFERENCE_COLOR_4)"
    
    if compare_colors "$current_color" "$REFERENCE_COLOR_4"; then
        log_success "Color matches! Clicking at (1044, 1176)..."
        tap_screen 1044 1176 "Matched button"
        sleep 8
        take_screenshot "after_1044_1176_click"
        
        log_info "Clicking comeback at (120, 2250)..."
        tap_screen 120 2250 "Comeback button"
        sleep 4
        
        # Check if re-click is needed by checking color at (98, 2260)
        local check_color=$(get_pixel_color 98 2260)
        log_info "Checking duplicate at (98, 2260): RGB($check_color) vs RGB($DUPLICATE_CHECK_COLOR)"
        
        if compare_colors "$check_color" "$DUPLICATE_CHECK_COLOR"; then
            log_warning "Re-click needed! Waiting 6 seconds..."
            sleep 6
            
            log_info "Re-clicking at (1044, 1176)..."
            tap_screen 1044 1176 "Re-click button"
            sleep 4
            
            log_info "Clicking comeback at (120, 2250)..."
            tap_screen 120 2250 "Comeback button"
            sleep 4
        fi
    else
        log_warning "Color does not match, skipping click"
    fi
    
    # ============================================
    # STEP 15: Click at (530, 400), wait, screenshot, then close popup
    # ============================================
    echo ""
    log_info "Clicking at (530, 400)..."
    tap_screen 530 400 "Button"
    sleep 1
    take_screenshot "after_530_400_click"
    
    log_info "Clicking popup X button at ($POPUP_X_BUTTON_X, $POPUP_X_BUTTON_Y)..."
    tap_screen $POPUP_X_BUTTON_X $POPUP_X_BUTTON_Y "Popup X button"
    
    echo ""
    echo "=========================================="
    log_success "Game flow automation complete!"
    log_info "Popups closed: $popups_closed"
    log_info "Total screenshots taken: $((screenshot_num - 1))"
    log_info "Screenshots saved to: $SCREENSHOT_DIR"
    echo "=========================================="
    
    # ============================================
    # Upload screenshots to Slack
    # ============================================
    echo ""
    log_info "Uploading screenshots to Slack..."
    
    # Get current date for the run
    local run_date=$(date +"%Y-%m-%d %H:%M")
    
    # Find all screenshots from this run (today's date)
    local today=$(date +"%Y%m%d")
    local uploaded=0
    local total_files=0
    local batch_count=0
    local BATCH_SIZE=5
    
    # Clean up any previous batch file
    rm -f /tmp/slack_batch.txt
    
    # Count total files first
    for screenshot in $(ls -1 "$SCREENSHOT_DIR"/*.png 2>/dev/null | grep "$today" | sort); do
        ((total_files++))
    done
    
    log_info "Found $total_files screenshots to upload (batching $BATCH_SIZE at a time)"
    
    # Send summary message first
    curl -s -X POST "https://slack.com/api/chat.postMessage" \
        -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
        -H "Content-Type: application/json; charset=utf-8" \
        -d "{\"channel\": \"$SLACK_CHANNEL_ID\", \"text\": \"📱 Fish of Fortune Screenshot Run Complete - $run_date - Screenshots: $total_files\"}" > /dev/null
    
    # Upload files in batches of 5
    for screenshot in $(ls -1 "$SCREENSHOT_DIR"/*.png 2>/dev/null | grep "$today" | sort); do
        local filename=$(basename "$screenshot")
        local filesize=$(stat -f%z "$screenshot")
        log_info "Uploading: $filename"
        
        # Step 1: Get upload URL
        local upload_response=$(curl -s -X POST "https://slack.com/api/files.getUploadURLExternal" \
            -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "filename=$filename&length=$filesize")
        
        local upload_url=$(echo "$upload_response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('upload_url',''))" 2>/dev/null)
        local file_id=$(echo "$upload_response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_id',''))" 2>/dev/null)
        
        if [ -z "$upload_url" ] || [ -z "$file_id" ]; then
            log_error "Failed to get upload URL for: $filename"
            continue
        fi
        
        # Step 2: Upload the file to the URL
        curl -s -X POST "$upload_url" -F "file=@$screenshot" > /dev/null
        
        # Add to batch - write to temp file
        echo "$file_id|$filename" >> /tmp/slack_batch.txt
        ((batch_count++))
        ((uploaded++))
        
        # Complete batch when we reach BATCH_SIZE or last file
        if [ $batch_count -ge $BATCH_SIZE ] || [ $uploaded -eq $total_files ]; then
            log_info "Sharing batch of $batch_count files..."
            
            # Use Python to read temp file and send batch
            python3 -c "
import json
import urllib.request

files = []
with open('/tmp/slack_batch.txt', 'r') as f:
    for line in f:
        parts = line.strip().split('|')
        if len(parts) == 2:
            files.append({'id': parts[0], 'title': parts[1]})

if files:
    data = {'files': files, 'channel_id': '$SLACK_CHANNEL_ID'}
    req = urllib.request.Request(
        'https://slack.com/api/files.completeUploadExternal',
        data=json.dumps(data).encode('utf-8'),
        headers={
            'Authorization': 'Bearer $SLACK_BOT_TOKEN',
            'Content-Type': 'application/json; charset=utf-8'
        }
    )
    try:
        with urllib.request.urlopen(req) as response:
            result = json.loads(response.read().decode('utf-8'))
            print('OK' if result.get('ok') else 'FAIL: ' + result.get('error', 'unknown'))
    except Exception as e:
        print('ERROR: ' + str(e))
"
            
            log_success "Batch shared! $uploaded of $total_files"
            
            # Reset batch
            rm -f /tmp/slack_batch.txt
            batch_count=0
        fi
    done
    
    echo ""
    log_success "Uploaded $uploaded screenshots to Slack #screenshots"
    echo "=========================================="
    
    # ============================================
    # Close the app on the device and remove from recents
    # ============================================
    echo ""
    log_info "Closing Fish of Fortune app..."
    
    # Force stop the app
    adb -s "$DEVICE_IP" shell am force-stop "$PACKAGE_NAME"
    
    # Go to Home screen
    adb -s "$DEVICE_IP" shell input keyevent KEYCODE_HOME
    sleep 0.5
    
    # Open recent apps and clear all (swipe to dismiss)
    adb -s "$DEVICE_IP" shell input keyevent KEYCODE_APP_SWITCH
    sleep 0.5
    
    # Clear all recent apps (tap "Clear all" button - usually at center top or swipe up)
    adb -s "$DEVICE_IP" shell input swipe 540 1000 540 200 200
    sleep 0.5
    
    # Go back to home
    adb -s "$DEVICE_IP" shell input keyevent KEYCODE_HOME
    sleep 0.5
    
    # Turn off the screen
    log_info "Turning off screen..."
    adb -s "$DEVICE_IP" shell input keyevent KEYCODE_POWER
    
    log_success "App closed, removed from recents, and screen turned off!"
    
    # ============================================
    # Delete screenshots from computer
    # ============================================
    echo ""
    log_info "Cleaning up screenshots from computer..."
    local deleted=0
    for screenshot in $(ls -1 "$SCREENSHOT_DIR"/*.png 2>/dev/null | grep "$today" | sort); do
        rm -f "$screenshot"
        ((deleted++))
    done
    log_success "Deleted $deleted screenshots from $SCREENSHOT_DIR"
    echo "=========================================="
}

# Run the automation
run_game_flow
