# Oculus Quest Apps in Zig

![Project banner](design/logo.png)

This repository contains a example on how to create a minimal Oculus Quest app in Zig.

This is a proof of concept, and is not suitable for production use.  PLEASE DON'T BUILD ACTUAL APPS WITH THIS TEMPLATE!  The threading model between the event threads and main thread needs revising to be considered robust, and the bindings to vrapi are largely untested, aside from what is present in the example.  Also, Zig as a whole is not ready for production use yet.

## State of the project

This project contains a small app skeleton in `example/main.zig` which renders a field of spinning cubes, based on the cube world sample from the Oculus SDK.  `build.zig` is an example project build file, and `Sdk.zig` contains the reusable components of the build.

This project is looking for a maintainer!  If you would like to take on the responsibility of updating this to new versions of zig, or adding missing examples, please reach out!

## What's missing

- Input handling example
- Texture loading example
- Network services examples
- Configuration management example
- Save/load app state example

## Requirements & Build

You need the [Android SDK](https://developer.android.com/studio#command-tools) installed together with the [Android NDK](https://developer.android.com/ndk).

You also need [adb](https://developer.android.com/studio/command-line/adb) and a Java SDK installed (required for `jarsigner`).

Then, you will need to install the [Oculus Quest SDK](https://developer.oculus.com/downloads/package/oculus-mobile-sdk/).  Unzip this into your checkout as `quest_sdk`, so that `quest_sdk/VrApi/Libs/Android/...` can be found by the build script.

Finally, you will need to add the [Oculus Spatial Audio SDK](https://developer.oculus.com/downloads/package/oculus-spatializer-native/).  Unzip this into the quest_sdk folder so that `quest_sdk/AudioSDK/Lib/Android/...` can be found by the build script.

In order to sideload applications onto your Quest or Quest 2, you will also need to [create an Oculus Developer Account](https://developer.oculus.com/manage/organizations/create/) and [put your device into developer mode](https://developer.oculus.com/documentation/native/android/mobile-device-setup/#enable-developer-mode).

Now you need to generate yourself a keystore to sign your apps. For debugging purposes, the build script contains a helper. Just invoke `zig build keystore` to generate yourself a debug keystore that can be used with later build invocations.

**Note** that the build file might ask you to configure some paths. Do as requested and just run the build again, it should work then.

If all of the above is done, you should be able to build the app by running `zig build`.

There are convenience options with `zig build push` (installs the app on a connected headset) and `zig build run` (which runs the app).

### Quick Start

Download the [Oculus Quest SDK](https://developer.oculus.com/downloads/package/oculus-mobile-sdk/).  Save this into your checkout as `quest_sdk/`, so that `quest_sdk/VrApi/Libs/Android/...` can be found by the build script.

In order to sideload applications onto your Quest or Quest 2, you will also need to [create an Oculus Developer Account](https://developer.oculus.com/manage/organizations/create/) and [put your device into developer mode](https://developer.oculus.com/documentation/native/android/mobile-device-setup/#enable-developer-mode).

Install the Android [`sdkmanager`](https://developer.android.com/studio/command-line/sdkmanager) and invoke the following command line:

```
sdkmanager --install "platforms;android-28"
sdkmanager --install "build-tools;28.0.3"
sdkmanager --install "ndk;21.1.6352462"
zig build keystore install push run
```

This should build an APK and install it on your connected headset if possible.

## Getting started

Check out the [`build.zig`](build.zig) to see how to build a new Quest app, and [`example/main.zig`](example/main.zig) to see how to create a basic application. All of this is still very rough, though.

## Troubleshooting

#### The build script is using the wrong Android SDK, NDK, or Java installation

You can manually edit `.build_config/android.json` to change which sdk paths are used.

#### `jarsigner error: java.lang.RuntimeException: keystore load: .../.build_config/debug.keystore (The system cannot find the file specified)`

This happens if you have not generated a keystore to sign the app.  Generate a debug one with `zig build keystore`.

#### `keytool error: java.lang.Exception: Key pair not generated, alias <default> already exists`

This happens if you run `zig build keystore` more than once.  You only need to run this build once, when setting up the repo.

## Credits

This project is based on the [ZigAndroidTemplate](https://github.com/MasterQ32/ZigAndroidTemplate) project by [@MasterQ32](https://github.com/MasterQ32/)

Huge thanks to [@cnlohr](https://github.com/cnlohr) to create [rawdrawandroid](https://github.com/cnlohr/rawdrawandroid) and making this project possible!

