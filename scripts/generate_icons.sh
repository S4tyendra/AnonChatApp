#!/bin/bash
set -e

# Configuration
SOURCE_IMAGE="image.png"
BG_COLOR="#13182B"
RES_DIR="android/app/src/main/res"

# Ensure source exists
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "Error: $SOURCE_IMAGE not found!"
    exit 1
fi

# Ensure directories exist
mkdir -p "$RES_DIR/mipmap-mdpi"
mkdir -p "$RES_DIR/mipmap-hdpi"
mkdir -p "$RES_DIR/mipmap-xhdpi"
mkdir -p "$RES_DIR/mipmap-xxhdpi"
mkdir -p "$RES_DIR/mipmap-xxxhdpi"
mkdir -p "$RES_DIR/mipmap-anydpi-v26"
mkdir -p "$RES_DIR/values"

# Function to generate legacy, foreground, and monochrome icons
generate_icons() {
    local density=$1
    local legacy_size=$2
    local adaptive_size=$3
    local dir="$RES_DIR/mipmap-$density"

    echo "Generating icons for $density..."

    # 1. Legacy Icon (ic_launcher.png)
    # Background + Logo centered (resized to ~70% to allow padding)
    # Using -gravity center and -composite
    magick -size ${legacy_size}x${legacy_size} xc:"$BG_COLOR" \
        \( "$SOURCE_IMAGE" -resize "$((legacy_size * 70 / 100))x$((legacy_size * 70 / 100))" \) \
        -gravity center -composite \
        "$dir/ic_launcher.png"

    # 2. Adaptive Foreground (ic_launcher_foreground.png)
    # Just the image, resized to fit within the safe zone (66dp out of 108dp base).
    # 66/108 ~= 61%. Let's go with 60% of the full usage size to be safe, centered.
    # Actually, the foreground layer is 108x108. The logo should typically fit in the center 66x66.
    magick -size ${adaptive_size}x${adaptive_size} xc:none \
        \( "$SOURCE_IMAGE" -resize "$((adaptive_size * 60 / 100))x$((adaptive_size * 60 / 100))" \) \
        -gravity center -composite \
        "$dir/ic_launcher_foreground.png"

    # 3. Monochrome Icon (ic_launcher_monochrome.png)
    # Flat white version of the logo (alpha channel preserved)
    magick -size ${adaptive_size}x${adaptive_size} xc:none \
        \( "$SOURCE_IMAGE" -resize "$((adaptive_size * 60 / 100))x$((adaptive_size * 60 / 100))" -alpha extract -background white -alpha shape -fill white -colorize 100 \) \
        -gravity center -composite \
        "$dir/ic_launcher_monochrome.png"
    
    # 4. Round Icon (ic_launcher_round.png) - Legacy
    # Circle mask on the legacy icon
    magick "$dir/ic_launcher.png" \
        \( +clone -threshold -1 -negate -fill white -draw "circle $((legacy_size/2)),$((legacy_size/2)) $((legacy_size/2)),0" \) \
        -alpha off -compose copy_opacity -composite \
        "$dir/ic_launcher_round.png"
}

# Generate for all densities
generate_icons "mdpi" 48 108
generate_icons "hdpi" 72 162
generate_icons "xhdpi" 96 216
generate_icons "xxhdpi" 144 324
generate_icons "xxxhdpi" 192 432

# Create ic_launcher.xml (Adaptive Icon)
cat > "$RES_DIR/mipmap-anydpi-v26/ic_launcher.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
EOF

# Create ic_launcher_round.xml (Adaptive Round Icon)
# Usually reuses the same adaptive definition or just points to the round pngs for legacy? 
# Android adaptive icons don't strictly have a "round" xml, the system decides the shape.
# But often projects have a separate one. Let's just point to the same adaptive icon definition 
# because adaptive icons adapt to the system shape (circle/squircle/etc).
cp "$RES_DIR/mipmap-anydpi-v26/ic_launcher.xml" "$RES_DIR/mipmap-anydpi-v26/ic_launcher_round.xml"

# Create colors.xml entry for background
# We need to be careful not to overwrite existing colors.xml. 
# Better to create a separate values file or append.
# Let's write to a dedicated file for the launcher background to avoid conflicts: values/ic_launcher_background.xml
cat > "$RES_DIR/values/ic_launcher_background.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">$BG_COLOR</color>
</resources>
EOF

echo "Icons generated successfully in $RES_DIR"
