The FFmpeg code used in VPlayer for Android
===========================================

This project includes the shell script to build FFmpeg for Android.


Build
-----

http://vec.io/posts/how-to-build-ffmpeg-with-android-ndk

0. Install git, Android ndk
1. `$ export ANDROID_NDK=/path/to/your/android-ndk`
2. `$ ./FFmpeg-Android.sh`
3. libffmpeg.so will be built to `build/ffmpeg/{neon,armv7,vfp,armv6,x86}/`
