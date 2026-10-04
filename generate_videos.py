import os
import subprocess

categories = ['fashion', 'beauty', 'travel', 'food', 'diy']
audio_map = {
    'fashion': 'assets/audio/upbeat_pop.wav',
    'beauty': 'assets/audio/lofi_chill.wav',
    'travel': 'assets/audio/acoustic_travel.wav',
    'food': 'assets/audio/bossa_nova.wav',
    'diy': 'assets/audio/lofi_chill.wav',
}

for cat in categories:
    out_dir = f"assets/videos/categories/{cat}"
    os.makedirs(out_dir, exist_ok=True)
    audio = audio_map[cat]
    cat_cap = cat.capitalize()
    
    for i in range(1, 6):
        img_name = f"{cat_cap}_{i:02d}.png"
        vid_name = f"{cat}_{i:02d}.mp4"
        img_path = f"assets/images/categories/{cat}/{img_name}"
        out_path = f"{out_dir}/{vid_name}"
        
        if os.path.exists(img_path):
            cmd = [
                "ffmpeg", "-y",
                "-loop", "1", "-i", img_path,
                "-i", audio,
                "-vf", "scale=720:1280:force_original_aspect_ratio=increase,crop=720:1280,zoompan=z='min(zoom+0.0015,1.5)':d=150:s=720x1280",
                "-c:v", "libx264", "-preset", "fast",
                "-b:v", "1M", "-maxrate", "1.5M", "-bufsize", "2M", "-crf", "28",
                "-pix_fmt", "yuv420p",
                "-c:a", "aac", "-b:a", "64k",
                "-shortest", "-t", "6",
                out_path
            ]
            subprocess.run(cmd, check=True)
            print(f"Successfully generated {out_path}")
        else:
            print(f"Missing image: {img_path}")
