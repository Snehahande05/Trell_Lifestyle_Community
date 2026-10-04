#!/bin/bash
cd /Users/snehahande/Desktop/trell_lifestyle_community

mkdir -p assets/videos/categories/fashion
mkdir -p assets/videos/categories/beauty
mkdir -p assets/videos/categories/travel
mkdir -p assets/videos/categories/food
mkdir -p assets/videos/categories/diy

generate_video() {
    img=$1
    out=$2
    audio=$3
    # Smooth Ken Burns zoom/pan effect, scaled to 720x1280 (9:16) with optimized H.264 compression & AAC audio
    ffmpeg -loop 1 -i "$img" -i "$audio" \
      -vf "scale=-1:1280,crop=720:1280,zoompan=z='min(zoom+0.0015,1.5)':d=150:s=720x1280" \
      -c:v libx264 -preset fast -b:v 1M -maxrate 1.5M -bufsize 2M -crf 28 -pix_fmt yuv420p \
      -c:a aac -b:a 64k -shortest -t 6 -y "$out"
}

for cat in fashion beauty travel food diy; do
    case $cat in
        fashion) AUDIO="assets/audio/upbeat_pop.wav" ;;
        beauty) AUDIO="assets/audio/lofi_chill.wav" ;;
        travel) AUDIO="assets/audio/acoustic_travel.wav" ;;
        food) AUDIO="assets/audio/bossa_nova.wav" ;;
        diy) AUDIO="assets/audio/lofi_chill.wav" ;;
    esac
    for i in 1 2 3 4 5; do
        cat_cap="$(tr '[:lower:]' '[:upper:]' <<< ${cat:0:1})${cat:1}"
        img_name=$(printf "%s_%02d.png" "$cat_cap" "$i")
        vid_name=$(printf "%s_%02d.mp4" "$cat" "$i")
        img="assets/images/categories/$cat/$img_name"
        out="assets/videos/categories/$cat/$vid_name"
        if [ -f "$img" ]; then
            echo "Generating compressed $out with audio $AUDIO"
            generate_video "$img" "$out" "$AUDIO"
        else
            echo "Missing image: $img"
        fi
    done
done
