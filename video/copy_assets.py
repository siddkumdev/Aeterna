"""Copy the game's own fonts and music into video/public (git-ignored copies): python video/copy_assets.py"""
import shutil
from pathlib import Path

root = Path(__file__).resolve().parent.parent
pub = root / "video" / "public"
for src, dst in [
    ("godot/assets/fonts/cinzel/Cinzel.ttf", "fonts/Cinzel.ttf"),
    ("godot/assets/fonts/ebgaramond/EBGaramond.ttf", "fonts/EBGaramond.ttf"),
    ("godot/assets/fonts/ebgaramond/EBGaramond-Italic.ttf", "fonts/EBGaramond-Italic.ttf"),
    ("godot/assets/audio/music/day_music.wav", "music/day_music.wav"),
    ("godot/assets/audio/music/night_music.wav", "music/night_music.wav"),
    ("godot/assets/audio/music/story_music.ogg", "music/story_music.ogg"),
]:
    (pub / dst).parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / src, pub / dst)
print("copied")
