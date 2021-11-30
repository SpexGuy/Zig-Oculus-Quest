//! This is a example build.zig!
//! Use it as a template for your own projects, all generic build instructions
//! are contained in Sdk.zig.

const std = @import("std");
const Sdk = @import("Sdk.zig");

pub fn build(b: *std.build.Builder) !void {
    // Default-initialize SDK
    const sdk = Sdk.init(b, null, .{});
    const mode = b.standardReleaseOptions();

    // Provide some KeyStore structure so we can sign our app.
    // Recommendation: Don't hardcore your password here, everyone can read it.
    // At least not for your production keystore ;)
    const key_store = Sdk.KeyStore{
        .file = ".build_config/debug.keystore",
        .alias = "default",
        .password = "ziguana",
    };

    // This is a configuration for your application.
    // Android requires several configurations to be done, this is a typical config
    const config = Sdk.AppConfig{
        // This is displayed to the user
        .display_name = "Zig Cube World Demo",

        // This is used internally for ... things?
        .app_name = "zig-cubeworld",

        // This is required for the APK name. This identifies your app, android will associate
        // your signing key with this identifier and will prevent updates if the key changes.
        .package_name = "org.zigulus.cubeworld",

        // This is a set of resources. It should at least contain a "mipmap/icon.png" resource that
        // will provide the application icon.
        .resources = &[_]Sdk.Resource{
            .{ .path = "mipmap/icon.png", .content = .{ .path = "example/icon.png" } },
        },

        // This is a list of android permissions. Check out the documentation to figure out which you need.
        .permissions = &[_][]const u8{
            "android.permission.SET_RELEASE_APP",
            //"android.permission.RECORD_AUDIO",
        },
    };

    const app = sdk.createApp(
        "org.zigulus.cubeworld.apk",
        "example/main.zig",
        config,
        mode,
        .{
            .aarch64 = b.option(bool, "aarch64", "Enable the aarch64 build") orelse true,
            .arm = b.option(bool, "arm", "Enable the arm build") orelse false,
        }, // default targets
        key_store,
    );

    for (app.libraries) |exe| {
        // Provide the "android" package in each executable we build
        exe.addPackage(app.getAndroidPackage("android"));
    }

    // Make the app build when we invoke "zig build" or "zig build install"
    b.getInstallStep().dependOn(app.final_step);

    const keystore_step = b.step("keystore", "Initialize a fresh debug keystore");
    const push_step = b.step("push", "Push the app to a connected android device");
    const run_step = b.step("run", "Run the app on a connected android device");
    const libs_step = b.step("libs", "Install all libraries to the prefix path");

    keystore_step.dependOn(sdk.initKeystore(key_store, .{}));
    push_step.dependOn(app.install());
    run_step.dependOn(app.run());

    for (app.libraries) |lib| {
        const install = b.addInstallArtifact(lib);
        libs_step.dependOn(&install.step);
    }
}
