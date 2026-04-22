# Third-party assets

Record every asset that is not original work here before shipping or redistributing the game. Many licenses (e.g. CC-BY) require attribution.

| Asset / pack | Author | License | Source | Notes |
|----------------|--------|---------|--------|-------|
| Animal pack (PNG Round subset in `assets/units/kenney_animal_pack/`) | Kenney (Kenney Vleugels) | CC0 | [kenney.nl](https://kenney.nl/assets) | Credit optional; see `License.txt` in that folder. |
| Tier 1 “Mite” sprites (`assets/units/mite_tier1/*.jpg`) | *(your generated art)* | *(per your AI/tool terms)* | — | Idle + 3 walk frames (JPEG); use `.jpg` extension if exports are not true PNG. Game keys out near-black as transparent. |
| Tier 2 “Striker” sprites (`assets/units/striker_tier2/*.jpg`) | *(your generated art)* | *(per your AI/tool terms)* | — | Same as Mite: idle + 3 walk; same animation + flip logic. |
| Sci-fi Sounds (`assets/audio/unit_attack.ogg`, `assets/audio/bunker_attack.ogg`, `assets/audio/bunker_destroyed.ogg`) | Kenney (Kenney Vleugels) | CC0 | [kenney.nl](https://kenney.nl/assets) | `explosionCrunch_000.ogg` → unit attacks; `laserLarge_004.ogg` → bunker defense; `explosionCrunch_002.ogg` → bunker destroyed. See `License.txt` next to the files. |
| Digital Audio (`assets/audio/unit_death.ogg`) | Kenney (Kenney Vleugels) | CC0 | [kenney.nl](https://kenney.nl/assets) | `zapThreeToneDown.ogg` → unit death. See `License_digital.txt` next to the files. |
| Match ambient music (`assets/audio/music/match_ambient.ogg`) | Lucas Calvo | *(per `mundosound.com` terms — attribution required)* | [mundosound.com](https://mundosound.com) | Original file: `Dark Atmosphere 13 Looped (24-bit) WAV`, transcoded to Vorbis (`ffmpeg -c:a libvorbis -q:a 5`). Looped in-engine via `MusicRouter`. |

## Folder layout (suggested)

- `res://assets/units/` — combat unit sprites, sheets, or atlases  
- `res://assets/ui/` — HUD, buttons, icons  
- `res://assets/audio/` — music and SFX  
- `res://assets/vfx/` — particles textures, decals  

Import files in the Godot editor; keep sources (e.g. zip or URL) in version control or your design notes if the license requires it.
