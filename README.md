# whisper-dictate-wayland

A system-wide voice dictation utility for Wayland

## Dependencies

Before installing, ensure the following utilities are available on your system:

- `quickshell` (for HUD overlay rendering)
- `cava` (for visualizer frequency streams)
- `ffmpeg` (for recording audio)
- `wl-clipboard` (for clipboard operations)
- `wtype` (for simulating keyboard input)
- `jq` (for API response parsing)
- `curl` (for API requests)

## Installation & Setup

1. Clone this repository to your system:
   ```bash
   git clone https://github.com/YOUR_USERNAME/whisper-dictate-wayland.git
   cd whisper-dictate-wayland
   ```

2. Make the script executable:
   ```bash
   chmod +x voice-dictate.sh
   ```

3. Copy the example configuration template:
   ```bash
   cp voice-dictate.conf.example voice-dictate.conf
   ```

4. Edit `voice-dictate.conf` and insert your Whisper API credentials:
   ```bash
   API_PROVIDER="groq" # or "openai"
   API_KEY="your_secret_api_key"
   ```

4.1. For groq

    go to `https://console.groq.com/` and create an API. 
    It is Free. Read the rate limits in their website. but it won't run out even if you spek for hours(single person atleast)

## Keybindings Integration (Hyprland Example)

To bind the dictation toggle to a key combination (e.g., `SUPER + SHIFT + V`),
add the following to your `hyprland.conf`:

```ini
bind = SUPER SHIFT, V, exec, /path/to/whisper-dictate-wayland/voice-dictate.sh
```
