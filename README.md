# Ports-and-Free-Games
A curation of ports and free games for spruceOS supported devices.

## How It Works

Games are organized into system group directories (e.g. `NES/`, `Game Boy/`, `Ports/`). Each game has its own subdirectory containing the game files and a `game.json` metadata file.

When the **Game Nursery Release** workflow is triggered (manually from the Actions tab), it:
1. Builds a `.7z` archive for every game
2. Generates the `nursery_config` used by the Game Nursery app on-device
3. Bundles all box art into `boxart.7z`
4. Uploads everything to the `Nursery` GitHub release

## Adding a Game to an Existing System

For example, adding a Game Boy game called "Cool Quest":

1. Create the directory structure:
   ```
   Game Boy/
     Cool Quest/
       Roms/
         GB/
           Cool Quest.gb
           Imgs/
             Cool Quest.png
       game.json
   ```

2. Use this template for `game.json`:
   ```json
   {
     "display": "Cool Quest",
     "shortname": "",
     "description": "A short description of the game.",
     "requires_files": false,
     "hidden": false
   }
   ```

3. Commit, push, and trigger the **Game Nursery Release** workflow from the Actions tab.

## Adding a Game for a New System

For example, adding a Game Boy Color game called "Tobu Tobu Girl DX":

1. Create a new top-level directory matching the system's display name and add the game:
   ```
   Game Boy Color/
     Tobu Tobu Girl DX/
       Roms/
         GBC/
           Tobu Tobu Girl DX.gbc
           Imgs/
             Tobu Tobu Girl DX.png
       game.json
   ```

2. Add the `game.json` as above.

3. Add the new system to `systems.json` in the repo root:
   ```json
   "Game Boy Color": { "icon": "gbc", "emu": "GBC" }
   ```
   - `icon` is the icon filename (without extension) used by spruceOS themes
   - `emu` is the Emu folder name on the device (e.g. `/mnt/SDCARD/Emu/GBC/`)

4. Commit, push, and trigger the workflow. No spruceOS app changes needed.

## game.json Reference

```json
{
  "display": "",
  "shortname": "",
  "description": "",
  "requires_files": false,
  "hidden": false
}
```

| Field | Description |
|-------|-------------|
| `display` | The name shown in the Game Nursery UI |
| `shortname` | Optional shorter name shown during download progress |
| `description` | Brief description of the game |
| `requires_files` | Set to `true` if the game needs additional commercial files to play |
| `hidden` | Set to `true` to build the archive but hide the game from the UI |

## Directory Structure

```
<System Group>/
  <Game Name>/
    game.json
    Roms/
      <SYSTEM_CODE>/
        <game files>
        Imgs/
          <Game Name>.png       (box art)
        licenses/
          <Game Name>.txt       (optional license file)
    BIOS/                       (optional, for games needing BIOS files)
    Emu/                        (optional, for emulator-specific files)
```

The box art image filename must match the `display` field in `game.json`.
