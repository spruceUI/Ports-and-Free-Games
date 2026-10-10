# lib/fallback

Shared libraries `liblove-11.5.so` links against, bundled so the app starts on any aarch64
spruceOS device even when the stock rootfs lacks one of them. `launch.sh` appends this
directory to the END of `LD_LIBRARY_PATH`, so a device's own copy always wins (verified on
TrimUI Smart Pro S and Miniloong: every one of these resolved from `/usr/lib` or
`spruce/flip/lib` before the fallback was consulted).

Not bundled on purpose: `libSDL2-2.0.so.0` (each platform ships an SDL2 built for its video
driver: stock on TrimUI/Flip/Miniloong, `App/PyUI/dll-mali` on Anbernic), `libz`, `libstdc++`,
`libgcc_s`, `libc` (must match the host glibc). `liblove-11.5.so` and `libluajit-5.1.so.2` live
in `../` and are loaded first.

All copies are aarch64 ELF taken unmodified from the spruceOS release tree
(`spruceUI/spruceOS`, branch Development, 2026-09); glibc symbol ceilings from `readelf -V`:

| file | taken from | glibc ceiling | licence |
|---|---|---|---|
| libmodplug.so.1 | spruce/flip/lib | 2.17 | public domain (libmodplug) |
| libtheoradec.so.1 | spruce/flip/lib | 2.17 | BSD (Xiph) |
| libogg.so.0 | spruce/flip/lib | 2.17 | BSD (Xiph) |
| libfreetype.so.6 | Emu/SCUMMVM/lib | 2.17 | FreeType License |
| libvorbisfile.so.3 | spruce/h700/ports-lib64 | 2.17 | BSD (Xiph) |
| libvorbis.so.0 | spruce/h700/ports-lib64 | 2.29 | BSD (Xiph) |
| libmpg123.so.0 | spruce/h700/ports-lib64 | 2.29 | LGPL-2.1 |
| libopenal.so.1 | spruce/h700/ports-lib64 | 2.33 | LGPL-2.0 (OpenAL Soft) |
| libatomic.so.1 | spruce/h700/ports-lib64 | 2.17 | GPL-3.0 with GCC Runtime Library Exception (needed by that libopenal build; absent from the Anbernic BaseOS rootfs) |

LGPL libraries are dynamically linked and replaceable by dropping another build in this
directory, which satisfies the LGPL relinking requirement.
