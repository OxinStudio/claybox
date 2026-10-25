# Third-party components

Claybox is built on, or ships with, the following projects. Thank you to everyone who made them.

| Component | Used for | Licence | Source |
|---|---|---|---|
| ScummVM | The game engine (Neverhood engine), patched by `claybox-hd.patch` | GNU GPL v3 or later | https://github.com/scummvm/scummvm |
| SDL 2 | Window, input and audio for the engine (linked statically in release builds) | zlib | https://github.com/libsdl-org/SDL |
| libpng | Reading HD images in the engine (linked statically in release builds) | libpng / PNG Reference Library licence | https://github.com/pnggroup/libpng |
| libjpeg-turbo | Reading HD video frames in the engine (linked statically in release builds) | IJG, BSD-3-Clause and zlib | https://github.com/libjpeg-turbo/libjpeg-turbo |
| realesrgan-ncnn-vulkan | The upscaler program, downloaded by `app/make-app.sh` and bundled in the app | MIT | https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan |
| Real-ESRGAN models | `realesrgan-x4plus` and `realesr-animevideov3` | BSD-3-Clause | https://github.com/xinntao/Real-ESRGAN |
| ncnn | Neural network runtime inside the upscaler | BSD-3-Clause | https://github.com/Tencent/ncnn |

`app/Sources/Claybox/GameData.swift` contains a Swift port of the PKWARE DCL "implode" decompressor, based on `blast.c` by Mark Adler (zlib licence), used to read the game’s archive files on the user’s Mac.

The full licence texts are included with each project at the source links above. The ScummVM licence files (`COPYING`, `LICENSES`, `AUTHORS`) are copied into the app bundle by `make-app.sh`.

Claybox contains no files, images, sounds or other content from *The Neverhood*.
