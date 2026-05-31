#!/usr/bin/env bash

# File paths for configuration and locks
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONF_FILE="$HOME/.config/voice-dictate.conf"
SECRETS_FILE="$HOME/.config/hypr/secrets/api-keys.conf"
LOCAL_CONF="$SCRIPT_DIR/voice-dictate.conf"
AUDIO_FILE="/tmp/voice.mp3"
LOCK_FILE="/tmp/voice-dictate.lock"
OVERLAY_PID_FILE="/tmp/voice-dictate-overlay.pid"

# Locate the QML overlay file in same directory or user config
if [ -f "$SCRIPT_DIR/voice-dictate-overlay.qml" ]; then
    OVERLAY_QML="$SCRIPT_DIR/voice-dictate-overlay.qml"
else
    OVERLAY_QML="$HOME/.config/hypr/scripts/voice-dictate-overlay.qml"
fi

# Load configurations if they exist
[ -f "$LOCAL_CONF" ] && source "$LOCAL_CONF"
[ -f "$CONF_FILE" ] && source "$CONF_FILE"
[ -f "$SECRETS_FILE" ] && source "$SECRETS_FILE"

# Resolve API keys from configuration or environment
[ -z "$API_KEY" ] && [ -n "$GROQ_API_KEY" ] && API_KEY="$GROQ_API_KEY"
[ -z "$API_KEY" ] && [ -n "$OPENAI_API_KEY" ] && API_KEY="$OPENAI_API_KEY"

# Ensure API key is present
if [ -z "$API_KEY" ]; then
    notify-send -a "Voice Dictation" -i dialog-warning "API Key Missing" \
        "Add your key to voice-dictate.conf, environment variables, or ~/.config/hypr/secrets/api-keys.conf"
    exit 0
fi

# Toggle recording or start transcription
if [ -f "$LOCK_FILE" ]; then
    # Stop recording and start transcription
    RECORD_PID=$(cat "$LOCK_FILE")
    kill "$RECORD_PID" 2>/dev/null
    rm -f "$LOCK_FILE"
    
    # Transition overlay to transcribing state
    qs -p "$OVERLAY_QML" ipc call voice-dictate-overlay setState transcribing >/dev/null 2>&1 || true
    
    # Wait for audio encoding to complete
    sleep 0.5
    
    # Check if recording output exists
    if [ ! -s "$AUDIO_FILE" ]; then
        qs -p "$OVERLAY_QML" ipc call voice-dictate-overlay setState error >/dev/null 2>&1 || true
        rm -f "$OVERLAY_PID_FILE"
        exit 1
    fi
    
    # Select API endpoint and model parameters
    if [ "$API_PROVIDER" = "groq" ]; then
        API_URL="https://api.groq.com/openai/v1/audio/transcriptions"
        MODEL_NAME="whisper-large-v3"
    else
        API_URL="https://api.openai.com/v1/audio/transcriptions"
        MODEL_NAME="whisper-1"
    fi
    
    # Dispatch transcription API request
    RESPONSE=$(curl -s -X POST "$API_URL" \
         -H "Authorization: Bearer $API_KEY" \
         -F "file=@$AUDIO_FILE" \
         -F "model=$MODEL_NAME" \
         -F "response_format=json")
         
    # Parse transcript text
    transcription=$(echo "$RESPONSE" | jq -r '.text' 2>/dev/null)
    
    # Handle response errors
    if [ "$transcription" = "null" ] || [ -z "$transcription" ]; then
        qs -p "$OVERLAY_QML" ipc call voice-dictate-overlay setState error >/dev/null 2>&1 || true
        rm -f "$OVERLAY_PID_FILE"
        rm -f "$AUDIO_FILE"
        exit 1
    fi
    
    # Copy text to both clipboard and primary selection to support terminal pasting
    echo -n "$transcription" | wl-copy
    echo -n "$transcription" | wl-copy -p
    wtype -M shift -k Insert
    
    # Signal success to the overlay HUD
    qs -p "$OVERLAY_QML" ipc call voice-dictate-overlay setState success >/dev/null 2>&1 || true
    rm -f "$OVERLAY_PID_FILE"
    rm -f "$AUDIO_FILE"

else
    # Start voice recording
    rm -f "$AUDIO_FILE"
    
    # Check if microphone is muted
    IS_MUTED=$(pactl get-source-mute $(pactl get-default-source) 2>/dev/null | awk '{print $2}')
    
    # Get active system audio source
    MIC_DEVICE=$(pactl get-default-source)
    
    # Write configuration for visualizer CAVA stream
    cat << EOF > /tmp/cava-dictate.conf
[general]
bars = 8
framerate = 60

[input]
method = pulse
source = $MIC_DEVICE

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
frame_delimiter = 10

[smoothing]
monstercat = 1
waves = 1
noise_reduction = 0.88
integral = 85
gravity = 80
ignore = 3
EOF

    # Start audio capture
    ffmpeg -f pulse -i "$MIC_DEVICE" -acodec libmp3lame -y "$AUDIO_FILE" >/dev/null 2>&1 &
    echo "$!" > "$LOCK_FILE"
    
    # Clean up lingering overlays
    if [ -f "$OVERLAY_PID_FILE" ]; then
        OLD_PID=$(cat "$OVERLAY_PID_FILE")
        kill "$OLD_PID" 2>/dev/null
        rm -f "$OVERLAY_PID_FILE"
    fi
    
    # Run the visualization overlay HUD
    quickshell -p "$OVERLAY_QML" >/dev/null 2>&1 &
    echo "$!" > "$OVERLAY_PID_FILE"
    
    # Alert overlay if recording while muted
    if [ "$IS_MUTED" = "yes" ]; then
        (sleep 0.25 && qs -p "$OVERLAY_QML" ipc call voice-dictate-overlay setState muted >/dev/null 2>&1) &
    fi
fi
