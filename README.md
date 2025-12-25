# Fish of Fortune Screenshot Automation

Automated scripts for capturing screenshots from the Fish of Fortune mobile game using ADB.

## Requirements

- macOS with Python 3
- ADB (Android Debug Bridge) installed
- Android device connected via network (TCP/IP)

## Scripts

### `fof_game_flow.sh`
The main automation script that:
1. Wakes the phone
2. Launches Fish of Fortune game
3. Clicks the Guest button to login
4. Automatically closes popups (detects when done via pixel color)
5. Navigates through menus
6. Takes screenshots at various points
7. Performs color-based UI element detection and clicks

### `fof_screenshot_automation.sh`
A simpler script for basic screenshot automation.

## Configuration

Edit the scripts to update:
- `DEVICE_IP` - Your Android device's IP address (default: `10.10.0.114:5555`)
- Button coordinates if the game UI changes

## Usage

```bash
# Make executable (first time only)
chmod +x fof_game_flow.sh

# Run the automation
./fof_game_flow.sh
```

## How It Works

The script uses ADB commands to:
- `input tap X Y` - Tap at specific coordinates
- `input swipe X1 Y1 X2 Y2` - Swipe/scroll gestures
- `screencap` - Capture screenshots
- Pixel color detection for smart popup handling

## Screenshots

Screenshots are saved with descriptive names and timestamps:
- `01_game_loaded_YYYYMMDD_HHMMSS.png`
- `02_after_guest_click_YYYYMMDD_HHMMSS.png`
- etc.

## License

MIT
