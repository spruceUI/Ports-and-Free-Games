# Ports-and-Free-Games

A curation of ports and free games for spruceOS supported devices.

## How It Works

Games are organized into system group directories (e.g. `NES/`, `Game Boy/`, `Ports/`). Each game has its own subdirectory containing the game files and a metadata file: either `game.json` or `game_v2.json`.

When the **Game Nursery Release** workflow is triggered manually from the Actions tab, it:

1. Builds a `.7z` archive for every game.
2. Generates `nursery_config` for the existing Game Nursery app.
3. Generates `nursery_config_v2`, including the v2-only entries and their compatibility metadata.
4. Bundles all box art into a shared `boxart.7z`.
5. Uploads everything to the `Nursery` GitHub release.

Games using `game.json` are included in both configs. Games using `game_v2.json` are included only in `nursery_config_v2`.

**Important:** Each game directory must contain either `game.json` or `game_v2.json`, not both.

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

   * `icon` is the icon filename (without extension) used by spruceOS themes.
   * `emu` is the Emu folder name on the device (e.g. `/mnt/SDCARD/Emu/GBC/`).

4. Commit, push, and trigger the workflow. No spruceOS app changes are needed for a standard `game.json` entry.

## Adding a v2 Game

Use `game_v2.json` for a game that should be listed only in `nursery_config_v2` and needs compatibility metadata.

The directory structure is the same as for a standard game, but use `game_v2.json` instead of `game.json`:

```
Game Boy/
  Cool Quest/
    Roms/
      GB/
        Cool Quest.gb
        Imgs/
          Cool Quest.png
    game_v2.json
```

Example `game_v2.json`:

```json
{
  "display": "Cool Quest",
  "shortname": "",
  "description": "A short description of the game.",
  "requires_files": false,
  "hidden": false,
  "min_cfw_version": "4.5.0",
  "devices": ["TRIMUI_BRICK", "MIYOO_FLIP"]
}
```

The standard metadata fields work the same way as in `game.json`. The additional fields are:

* `min_cfw_version`: Optional minimum spruceOS version required for the entry, expressed as a version string.
* `devices`: Optional array of supported device identifiers. Use the identifiers recognized by spruceOS for the intended devices.

Both compatibility fields are passed through to `nursery_config_v2` as separate top-level dictionaries, keyed by the entry's `System Group/Display Name`. For example:

```json
{
  "min_cfw_version": {
    "Game Boy/Cool Quest": "4.5.0"
  },
  "devices": {
    "Game Boy/Cool Quest": ["TG5040", "TG5050"]
  }
}
```

These fields are metadata for the device-side implementation to interpret. The release workflow does not itself enforce version or device compatibility.

A `game_v2.json` entry still gets an archive and can provide box art in the same way as a `game.json` entry. Setting `"hidden": true` builds the archive but omits the entry from the config and box art collection.

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

| Field            | Description                                                         |
| ---------------- | ------------------------------------------------------------------- |
| `display`        | The name shown in the Game Nursery UI                               |
| `shortname`      | Optional shorter name shown during download progress                |
| `description`    | Brief description of the game                                       |
| `requires_files` | Set to `true` if the game needs additional commercial files to play |
| `hidden`         | Set to `true` to build the archive but hide the game from the UI    |

## game_v2.json Reference

`game_v2.json` supports all the fields in `game.json`, plus the following optional fields:

| Field                | Description                                     |
| -------------------- | ----------------------------------------------- |
| `min_cfw_version` | Minimum spruceOS version required for the entry |
| `devices`            | Array of supported device identifiers           |

Example:

```json
{
  "display": "",
  "shortname": "",
  "description": "",
  "requires_files": false,
  "hidden": false,
  "min_cfw_version": "",
  "devices": []
}
```

## Directory Structure

```
<System Group>/
  <Game Name>/
    game.json OR game_v2.json
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

The box art image filename must match the `display` field in the metadata file.
