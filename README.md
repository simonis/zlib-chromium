# zlib-chromium

This is a fork of https://chromium.googlesource.com/chromium/src/third_party/zlib which is itself a fork of [Mark Adler's](http://en.wikipedia.org/wiki/Mark_Adler) [zlib](http://zlib.net/) from https://github.com/madler/zlib

zlib-chromium is part of the larger [Chromium project](https://chromium.googlesource.com/chromium) which comes with it's own build system. I've added a simple build script under `build/build.sh`. If called, it will build `libz.so` under `build/` and symlink it to `build/libz.so.1`.

See [README.chromium](./README.chromium) for zlib-chromium specific information.
