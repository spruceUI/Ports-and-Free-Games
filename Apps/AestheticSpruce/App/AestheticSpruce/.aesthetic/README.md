<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/banner_dark.webp">
  <source media="(prefers-color-scheme: light)" srcset=".github/banner_light.webp">
  <img alt="unofficial Aesthetic for Spruce" src=".github/banner_light.webp">
</picture>

<div align="center">
  <p>
    <b>Aesthetic Spruce</b> is an unofficial fork of <a href="https://github.com/joneavila/aesthetic"><b>Aesthetic</b></a> by Jonathan Avila, being reworked into a <a href="https://github.com/spruceUI/spruceOS">spruceOS</a> app that generates themes directly on your handheld.
  </p>
</div>

> [!IMPORTANT]
> **This repository is not affiliated with, endorsed by, or maintained by the original author, and it is not an official spruceUI project.**
> It is a community project whose only relationship to the original is that it started from its source code (MIT licensed), as a fork of `joneavila/aesthetic` at v1.10.1; the git history carries the original commits. "Spruce" in the name says which firmware it targets, nothing more.
> Do not report problems with *this* fork to the original author, and do not report problems with the original muOS app here.
>
> The original app is **Aesthetic for muOS** by **Jonathan Avila** ([@joneavila](https://github.com/joneavila)): https://github.com/joneavila/aesthetic

## ❤️ Support the original author

All of the design, the UI, the colour tooling and the theme pipeline this fork builds on were created by Jonathan Avila. If this project is useful to you, please support **them**, not this fork:

- Donate via the original author's Ko-fi: [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/F1F51COHHT)
- Star and use the original app: https://github.com/joneavila/aesthetic ([Releases](https://github.com/joneavila/aesthetic/releases), [wiki](https://github.com/joneavila/aesthetic/wiki), [muOS community thread](https://community.muos.dev/t/aesthetic-create-themes-directly-on-your-handheld))

This fork accepts no donations.

## 🌲 Aesthetic Spruce

Pick colours, a gradient, a font and a layout on the handheld; the app writes a complete PyUI theme to `Themes/<name>` and activates it.

<div align="center">
  <img alt="spruceOS main menu in eight built-in presets, list and grid" src=".github/preview-main-menu.gif" width="420">
  <img alt="spruceOS system menu in eight built-in presets, list and grid" src=".github/preview-systems.gif" width="420">
  <p><sub>Eight built-in presets on a MagicX Zero 28: the main menu (left) and the system menu (right), each split diagonally with the <b>list</b> layout above and the <b>grid</b> layout below. System icons use the <i>SPRUCE Mono</i> style. These are screenshots of the handheld, not mock-ups.</sub></p>
</div>

**Devices** (aarch64 spruceOS 4.3.x, 4.4.x and 4.5.x, tracked to 4.5.2 stable / 4.5.3 nightly)

- Verified on spruceOS 4.3.6: TrimUI Smart Pro S, TrimUI Brick Pro, Miyoo Flip, Miniloong Pocket 1, Anbernic RG35XX SP, Anbernic RG40XX-class 720x480. On 4.4.0: Miyoo Flip. On 4.4.3: MagicX Zero 28 and Zero 40. On 4.5.3: MagicX Zero 28 and Zero 40.
- Expected: TrimUI Brick and Smart Pro, GKD Pixel2, the rest of the Anbernic RG XX family, RGB30, and the MagicX Zero28, Zero 40 and XU20 (these need spruceOS 4.4.2 or a Development build; 4.4.1 has no MagicX support in its menu). On the RGB30 a Full spruce update resets the active theme to SPRUCE (spruce keeps that setting inside `App/PyUI`, which the update replaces); your theme folder is kept, re-select it under ***Settings*** > ***Theme***.
- Not supported: Miyoo A30 and the Mini family (32-bit, no LÖVE runtime).

**Build and run**

```
python3 -m pip install cairosvg lupa          # host tools: icon rasteriser, LuaJIT syntax check
./build.sh                                     # dist/sd-overlay/App/AestheticSpruce/ plus a .zip and a .7z of it
LOVE=/path/to/love ./dev_launch.sh 1280 720    # run on a workstation (LÖVE 11.5); .dev/ is the fake card
AESTHETIC_AUTOBUILD=1 AESTHETIC_PRESET=dmg ./dev_launch.sh 1280 720 && python3 utils/validate_theme.py .dev/Themes/DMG
```

**Docs**

- [DEVELOPMENT.md](DEVELOPMENT.md): how the app is built, how the theme model and renderers work, how to add an option, how to test on a device.
- [TODO.md](TODO.md): open items.

**Changes from upstream**

- Theme output is a renderer (`src/utils/skin_renderer.lua`, `icon_renderer.lua`, `pyui_config.lua`): PyUI themes are bitmap skins plus a `config.json`, not `.ini` schemes.
- TÖVE (native SVG) is gone; icons are rasterised on the host and tinted at runtime.
- muOS-only parts (launcher, `.muxupd` packaging, LVGL fonts, ImageMagick, RGB, `theme.sh`) are replaced by `spruce/launch.sh`, `build.sh`, TTF fonts, LÖVE canvases and a write to the device's system json.
- The editor UI, colour pickers, presets and settings are the original code.

**Contributing.** Open an issue or pull request on [this repository](https://github.com/CatalyticArkun/aesthetic-spruce). For the muOS app, use the [original repository](https://github.com/joneavila/aesthetic).

**AI disclosure.** This port was written with AI assistance (Claude), directed and tested by the maintainer on real devices. Throughout, the original author's attribution, credits and Ko-fi have been kept intact as far as possible; the design and the editor code are Jonathan Avila's work.

## ✨ Features

- **Theme customisation**
  - **Home Screen Layout**: grid of tiles or a text list
  - **Colors**: background and foreground from a palette, an HSV picker or a hex code; solid or two-colour gradient background
  - **Battery**: charging and low colours
  - **Font**: *Inter*, *Montserrat*, *Nunito*, *JetBrains Mono*, *Cascadia Code*, *Retro Pixel* or *Bitter*
  - **Icons**: system icon tiles on or off, drawn as a glyph per family (handheld, TV console, arcade, computer, engines and ports), as the first letter of the system's name, or as SPRUCE's own system art redrawn in the theme's two colours
  - **Bars**: title, clock, battery and button hints, each shown or hidden
  - **Box Art Width**: size of the box art next to the game list
  - **spruceOS Options**: view type for the game list, systems and apps; Recents, Collections and Favorites tiles; index counter; screensaver timeout
- **Theme management**
  - **Build**: writes a complete PyUI theme to `Themes/<name>` with the device's native resolution set and the 640x480 base set
  - **Activate**: switch to the new theme immediately, or later from Settings, Theme
  - **Auto-restore**: the app reopens with your last settings
  - **Presets**: 33 built in, plus your own — the originals (*Win95*, *Purple Noir*, *Terminal*, *Vaporwave*, *Orange Cream*, *DMG*, *Fami*, *Bumblebee*, *Mint*), ten RetroArch menu themes (*Dracula*, *Nord*, *Gruvbox Dark*, *Solarized Dark*, *Legacy Red*, *Midnight Blue*, *Volcanic Red*, *Dark Purple*, *Electric Blue*, *Undersea*), twelve classic-system palettes (*SNES*, *Genesis*, *GBC*, *GBA*, *Virtual Boy*, *Neo Geo*, *PC Engine*, *Atari 2600*, *C64*, *ZX Spectrum*, *Vectrex*, *Intellivision*) and *MinUI* in black and white
- **Compatibility check**: warns once at start if the card runs a spruceOS release the app was not built for (anything other than 4.3.x, 4.4.x or 4.5.x) or PyUI's theme loader has changed

## 📦 Installation

> [!IMPORTANT]
> Built for **spruceOS 4.3.x, 4.4.x and 4.5.x** on aarch64 devices (see Devices above). The Miyoo A30 and Mini family are not supported.

1. Get `AestheticSpruce_vX.Y.Z_sd-overlay.zip` from the [Releases](https://github.com/CatalyticArkun/aesthetic-spruce/releases) of this repository (stable releases are pinned from tested nightlies; nightlies are marked pre-release), or build it with `./build.sh`.
2. Unzip it onto the root of the spruceOS card, so that `App/AestheticSpruce` sits next to your other apps.
3. Launch ***Apps*** > ***Aesthetic Spruce***.

## ⚙️ Usage

1. From the main menu, pick the options to customise. Each screen shows its controls at the bottom; A confirms, B goes back, Start opens Settings.
2. Select **Build Theme** to write the theme to `Themes/<name>`.
3. Choose **Activate Now** to switch to it, or apply it later via ***Settings*** > ***Theme***.
4. Save and load presets from ***Settings*** (Start) > ***Save Theme Preset*** / ***Load Theme Preset***.

## ⭐ Credits

### Original project

- **Aesthetic** • Original application, design and source • [Jonathan Avila (@joneavila)](https://github.com/joneavila) • [MIT](LICENSE) • [Ko-fi](https://ko-fi.com/F1F51COHHT)

### Added by this fork

- Runtime libraries in `lib/fallback/` (OpenAL Soft LGPL-2.0, mpg123 LGPL-2.1, FreeType FTL, libvorbis/libogg/libtheora BSD, libmodplug public domain) taken unmodified from the spruceOS release tree; see [lib/fallback/PROVENANCE.md](lib/fallback/PROVENANCE.md). TÖVE is no longer shipped.
- Reference dimensions in `src/spruce/skin_spec.lua` are generated from the SPRUCE theme by tenlevels (spruceOS default theme, MIT). The *SPRUCE Art* (two tones) and *SPRUCE Mono* (one colour) icon styles recolour that theme's system art, read from the card at build time (nothing is bundled); generated themes credit it in their README.

### Original credits (kept intact from the upstream project)

- [**Bitter**](https://fonts.google.com/specimen/Bitter) • Font • [OFL-1.1](assets/fonts/bitter/OFL.txt)
- [**Cascadia Code**](https://github.com/microsoft/cascadia-code/) • Font • [OFL-1.1](assets/fonts/cascadia_code/LICENSE)
- [**Catppuccin Palettes**](https://github.com/catppuccin/palette) • Color palette • [MIT](https://github.com/catppuccin/palette/blob/main/LICENSE)
- [**Inter**](https://github.com/rsms/inter) • Font • [OFL-1.1](assets/fonts/inter/OFL.txt)
- [**json.lua**](https://github.com/rxi/json.lua) • JSON library • [MIT](src/json_lua/LICENSE.txt)
- [**Kenney Input Prompts**](https://kenney-assets.itch.io/input-prompts) • Icons • [CC0](assets/icons/kenney_input_prompts/License.txt)
- [**LÖVE**](https://github.com/love2d/love) • Game framework • [ZLIB](bin/LICENSE.txt)
- [**Lucide Icons**](https://github.com/lucide-icons/lucide) • Icons • [ISC](https://github.com/lucide-icons/lucide/blob/main/LICENSE)
- [**Material Icons**](https://github.com/google/material-design-icons) • Icons • [Apache 2.0](https://github.com/google/material-design-icons/blob/master/LICENSE)
- [**MinUI**](https://github.com/shauninman/MinUI) • Inspiration (design) • No license provided
- [**MinUIfied Theme Generator**](https://github.com/hmcneill46/muOS-MinUIfied-Theme-Generator) • Inspiration (application), reference for default theme • [MIT](https://github.com/hmcneill46/muOS-MinUIfied-Theme-Generator/blob/master/LICENSE)
- [**Montserrat**](https://github.com/googlefonts/montserrat) • Font • [OFL-1.1](assets/fonts/montserrat/OFL.txt)
- **muOS Theme by Bitter Bizarro** • Basis for theme scheme files
- [**Nunito**](https://github.com/googlefonts/nunito) • Font • [OFL-1.1](assets/fonts/nunito/OFL.txt)
- [**Retro Pixel Font**](https://github.com/TakWolf/retro-pixel-font) • Font • [OFL-1.1](assets/fonts/retro_pixel/LICENSE)
- [**TÖVE**](https://github.com/poke1024/tove2d) • LÖVE library • [MIT](src/tove/LICENSE)
- [**tween.lua**](https://github.com/kikito/tween.lua) • Tweening library • [MIT](https://github.com/kikito/tween.lua/blob/master/LICENSE.txt)

## ⚖️ License

This project is licensed under the MIT License. The original copyright notice, `Copyright (c) 2025 Jonathan Avila`, is preserved in [LICENSE](LICENSE) and must stay with any copy or substantial portion of this software. Changes made in this fork are released under the same license.
