//! External dependencies:
//! - `keytool`, `jarsigner` from OpenJDK
//! - `adb` from the Android tools package

const std = @import("std");
const builtin = @import("builtin");

const auto_detect = @import("build/auto-detect.zig");

fn sdkRoot() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

/// This file encodes a instance of an Android SDK interface.
const Sdk = @This();

/// The builder instance associated with this object.
b: *Builder,

/// A set of tools that run on the build host that are required to complete the 
/// project build. Must be created with the `hostTools()` function that passes in
/// the correct relpath to the package.
host_tools: HostTools,

/// The configuration for all non-shipped system tools.
/// Contains the normal default config for each tool.
system_tools: SystemTools = .{},

/// Contains paths to each required input folder.
folders: UserConfig,

versions: ToolchainVersions,

/// Initializes the android SDK.
/// It requires some input on which versions of the tool chains should be used
pub fn init(b: *Builder, user_config: ?UserConfig, versions: ToolchainVersions) *Sdk {
    // Make sure the oculus SDK is here
    {
        var quest_sdk = std.fs.cwd().openDir("quest_sdk", .{}) catch |err| {
            std.debug.print(
                \\Couldn't find the Oculus Mobile SDK.
                \\Please unzip it into ./quest_sdk
                \\Refer to README.md for more information.
                \\Error: {}
                \\
            , .{err});
            std.os.exit(1);
        };
        defer quest_sdk.close();

        var vrapi = quest_sdk.openDir("VrApi", .{}) catch |err| {
            std.debug.print(
                \\Found the Quest SDK at ./quest_sdk, but it is configured incorrectly.
                \\Please rearrange the files so that the "VrApi" folder in the SDK
                \\is at ./quest_sdk/VrApi .
                \\Refer to README.md for more information.
                \\Error: {}
                \\
            , .{err});
            std.os.exit(1);
        };
        defer vrapi.close();
    }

    const actual_user_config = user_config orelse auto_detect.findUserConfig(b, versions) catch |err| @panic(@errorName(err));

    const system_tools = blk: {
        const exe = if (builtin.os.tag == .windows) ".exe" else "";

        const zipalign = std.fs.path.join(b.allocator, &[_][]const u8{ actual_user_config.android_sdk_root, "build-tools", versions.build_tools_version, "zipalign" ++ exe }) catch unreachable;
        const aapt = std.fs.path.join(b.allocator, &[_][]const u8{ actual_user_config.android_sdk_root, "build-tools", versions.build_tools_version, "aapt" ++ exe }) catch unreachable;
        const adb = std.fs.path.join(b.allocator, &[_][]const u8{ actual_user_config.android_sdk_root, "platform-tools", "adb" ++ exe }) catch unreachable;
        const jarsigner = std.fs.path.join(b.allocator, &[_][]const u8{ actual_user_config.java_home, "bin", "jarsigner" ++ exe }) catch unreachable;
        const keytool = std.fs.path.join(b.allocator, &[_][]const u8{ actual_user_config.java_home, "bin", "keytool" ++ exe }) catch unreachable;

        break :blk SystemTools{
            .zipalign = zipalign,
            .aapt = aapt,
            .adb = adb,
            .jarsigner = jarsigner,
            .keytool = keytool,
        };
    };

    // Compiles all required additional tools for toolchain.
    const host_tools = blk: {
        const zip_add = b.addExecutable("zip_add", sdkRoot() ++ "/tools/zip_add.zig");
        zip_add.addCSourceFile(sdkRoot() ++ "/vendor/kuba-zip/zip.c", &[_][]const u8{
            "-std=c99",
            "-fno-sanitize=undefined",
        });
        zip_add.addIncludeDir(sdkRoot() ++ "/vendor/kuba-zip");
        zip_add.linkLibC();

        break :blk HostTools{
            .zip_add = zip_add,
        };
    };

    const sdk = b.allocator.create(Sdk) catch @panic("out of memory");
    sdk.* = Sdk{
        .b = b,
        .host_tools = host_tools,
        .system_tools = system_tools,
        .folders = actual_user_config,
        .versions = versions,
    };
    return sdk;
}

pub const ToolchainVersions = struct {
    android_sdk_version: u16 = 28,
    build_tools_version: []const u8 = "28.0.3",
    ndk_version: []const u8 = "21.1.6352462",

    pub fn androidSdkString(self: ToolchainVersions, buf: *[5]u8) []u8 {
        return std.fmt.bufPrint(buf, "{d}", .{self.android_sdk_version}) catch unreachable;
    }
};

pub const UserConfig = struct {
    android_sdk_root: []const u8 = "",
    android_ndk_root: []const u8 = "",
    java_home: []const u8 = "",
};

/// Configuration of the Android toolchain.
pub const Config = struct {
    /// Path to the SDK root folder.
    /// Example: `/home/ziggy/android-sdk`.
    sdk_root: []const u8,

    /// Path to the NDK root folder.
    /// Example: `/home/ziggy/android-sdk/ndk/21.1.6352462`.
    ndk_root: []const u8,

    /// Path to the build tools folder.
    /// Example: `/home/ziggy/android-sdk/build-tools/28.0.3`.
    build_tools: []const u8,

    /// A key store. This is required when an APK is created and signed.
    /// If you don't care for production code, just use the default here
    /// and it will work. This needs to be changed to a *proper* key store
    /// when you want to publish the app.
    key_store: KeyStore = KeyStore{
        .file = "zig-cache/",
        .alias = "default",
        .password = "ziguana",
    },
};

/// A resource that will be packed into the appliation.
pub const Resource = struct {
    /// This is the relative path to the resource root
    path: []const u8,
    /// This is the content of the file.
    content: std.build.FileSource,
};

/// Configuration of an application.
pub const AppConfig = struct {
    /// The display name of the application. This is shown to the users.
    display_name: []const u8,

    /// Application name, only lower case letters and underscores are allowed.
    app_name: []const u8,

    /// Java package name, usually the reverse top level domain + app name.
    /// Only lower case letters, dots and underscores are allowed.
    package_name: []const u8,

    /// The android version which is embedded in the manifset.
    /// This is usually the same version as of the SDK that was used, but might also be 
    /// overridden for a specific app.
    target_sdk_version: ?u16 = null,

    /// The resource directory that will contain the manifest and other app resources.
    /// This should be a distinct directory per app.
    resources: []const Resource = &[_]Resource{},

    /// If true, the app will be started in "fullscreen" mode, this means that
    /// navigation buttons as well as the top bar are not shown.
    /// This is usually relevant for games.
    fullscreen: bool = false,

    /// One or more asset directories. Each directory will be added into the app assets.
    asset_directories: []const []const u8 = &[_][]const u8{},

    permissions: []const []const u8 = &[_][]const u8{
        //"android.permission.SET_RELEASE_APP",
        //"android.permission.RECORD_AUDIO",
    },
};

/// One of the legal targets android can be built for.
pub const Target = enum {
    aarch64,
    arm,
    x86,
    x86_64,
};

pub const KeyStore = struct {
    file: []const u8,
    alias: []const u8,
    password: []const u8,
};

pub const HostTools = struct {
    zip_add: *std.build.LibExeObjStep,
};

/// Configuration of the binary paths to all tools that are not included in the android SDK.
pub const SystemTools = struct {
    //keytool: []const u8 = "keytool",
    //adb: []const u8 = "adb",
    //jarsigner: []const u8 = "/usr/lib/jvm/java-11-openjdk/bin/jarsigner",
    mkdir: []const u8 = "mkdir",
    rm: []const u8 = "rm",

    zipalign: []const u8 = "zipalign",
    aapt: []const u8 = "aapt",
    adb: []const u8 = "adb",
    jarsigner: []const u8 = "jarsigner",
    keytool: []const u8 = "keytool",
};

/// The configuration which targets a app should be built for.
pub const AppTargetConfig = struct {
    aarch64: bool = true,
    arm: bool = false, // re-enable when https://github.com/ziglang/zig/issues/8885 is resolved
    x86_64: bool = false,
    x86: bool = false,
};

pub const CreateAppStep = struct {
    sdk: *Sdk,
    first_step: *std.build.Step,
    final_step: *std.build.Step,

    libraries: []const *std.build.LibExeObjStep,
    build_options: *BuildOptionStep,

    apk_file: std.build.FileSource,

    package_name: []const u8,

    pub fn getAndroidPackage(self: @This(), name: []const u8) std.build.Pkg {
        return self.sdk.b.dupePkg(std.build.Pkg{
            .name = name,
            .path = .{ .path = sdkRoot() ++ "/src/android-support.zig" },
            .dependencies = &[_]std.build.Pkg{
                self.build_options.getPackage("build_options"),
            },
        });
    }

    pub fn install(self: @This()) *Step {
        return self.sdk.installApp(self.apk_file);
    }

    pub fn run(self: @This()) *Step {
        return self.sdk.startApp(self.package_name);
    }
};

/// Instantiates the full build pipeline to create an APK file.
///
pub fn createApp(
    sdk: *Sdk,
    apk_file: []const u8,
    src_file: []const u8,
    app_config: AppConfig,
    mode: std.builtin.Mode,
    targets: AppTargetConfig,
    key_store: KeyStore,
) CreateAppStep {
    const write_xml_step = sdk.b.addWriteFile("strings.xml", blk: {
        var buf = std.ArrayList(u8).init(sdk.b.allocator);
        errdefer buf.deinit();

        var writer = buf.writer();

        writer.writeAll(
            \\<?xml version="1.0" encoding="utf-8"?>
            \\<resources>
            \\
        ) catch unreachable;

        writer.print(
            \\    <string name="app_name">{s}</string>
            \\    <string name="lib_name">{s}</string>
            \\    <string name="package_name">{s}</string>
            \\
        , .{
            app_config.display_name,
            app_config.app_name,
            app_config.package_name,
        }) catch unreachable;

        writer.writeAll(
            \\</resources>
            \\
        ) catch unreachable;

        break :blk buf.toOwnedSlice();
    });

    const manifest_step = sdk.b.addWriteFile("AndroidManifest.xml", blk: {
        var buf = std.ArrayList(u8).init(sdk.b.allocator);
        errdefer buf.deinit();

        var writer = buf.writer();

        @setEvalBranchQuota(1_000_000);
        writer.print(
            \\<?xml version="1.0" encoding="utf-8" standalone="no"?><manifest xmlns:tools="http://schemas.android.com/tools" xmlns:android="http://schemas.android.com/apk/res/android" package="{s}">
            \\
        , .{app_config.package_name}) catch unreachable;
        for (app_config.permissions) |perm| {
            writer.print(
                \\    <uses-permission android:name="{s}"/>
                \\
            , .{perm}) catch unreachable;
        }

        if (app_config.fullscreen) {
            writer.writeAll(
                \\    <application android:debuggable="true" android:hasCode="false" android:label="@string/app_name" android:theme="@android:style/Theme.NoTitleBar.Fullscreen" tools:replace="android:icon,android:theme,android:allowBackup,label" android:icon="@mipmap/icon" >
                \\        <activity android:configChanges="keyboardHidden|orientation" android:name="android.app.NativeActivity">
                \\            <meta-data android:name="android.app.lib_name" android:value="@string/lib_name"/>
                \\            <intent-filter>
                \\                <action android:name="android.intent.action.MAIN"/>
                \\                <category android:name="android.intent.category.LAUNCHER"/>
                \\            </intent-filter>
                \\        </activity>
                \\    </application>
                \\</manifest>
                \\
            ) catch unreachable;
        } else {
            writer.writeAll(
                \\    <application android:debuggable="true" android:hasCode="false" android:label="@string/app_name" tools:replace="android:icon,android:theme,android:allowBackup,label" android:icon="@mipmap/icon">
                \\        <activity android:configChanges="keyboardHidden|orientation" android:name="android.app.NativeActivity">
                \\            <meta-data android:name="android.app.lib_name" android:value="@string/lib_name"/>
                \\            <intent-filter>
                \\                <action android:name="android.intent.action.MAIN"/>
                \\                <category android:name="android.intent.category.LAUNCHER"/>
                \\            </intent-filter>
                \\        </activity>
                \\    </application>
                \\</manifest>
                \\
            ) catch unreachable;
        }

        break :blk buf.toOwnedSlice();
    });

    const resource_dir_step = CreateResourceDirectory.create(sdk.b);
    for (app_config.resources) |res| {
        resource_dir_step.add(res);
    }
    resource_dir_step.add(Resource{
        .path = "values/strings.xml",
        .content = write_xml_step.getFileSource("strings.xml").?,
    });

    const sdk_version = sdk.versions.android_sdk_version;
    const target_sdk_version = app_config.target_sdk_version orelse sdk.versions.android_sdk_version;

    const root_jar = std.fs.path.resolve(sdk.b.allocator, &[_][]const u8{
        sdk.folders.android_sdk_root,
        "platforms",
        sdk.b.fmt("android-{d}", .{sdk_version}),
        "android.jar",
    }) catch unreachable;

    const make_unsigned_apk = sdk.b.addSystemCommand(&[_][]const u8{
        sdk.system_tools.aapt,
        "package",
        "-f", // force overwrite of existing files
        "-F", // specify the apk file to output
        sdk.b.pathFromRoot(apk_file),
        "-I", // add an existing package to base include set
        root_jar,
    });

    make_unsigned_apk.addArg("-M"); // specify full path to AndroidManifest.xml to include in zip
    make_unsigned_apk.addFileSourceArg(manifest_step.getFileSource("AndroidManifest.xml").?);

    make_unsigned_apk.addArg("-S"); // directory in which to find resources.  Multiple directories will be scanned and the first match found (left to right) will take precedence
    make_unsigned_apk.addFileSourceArg(resource_dir_step.getOutputDirectory());

    make_unsigned_apk.addArgs(&[_][]const u8{
        "-v",
        "--target-sdk-version",
        sdk.b.fmt("{d}", .{target_sdk_version}),
    });
    for (app_config.asset_directories) |dir| {
        make_unsigned_apk.addArg("-A"); // additional directory in which to find raw asset files
        make_unsigned_apk.addArg(sdk.b.pathFromRoot(dir));
    }

    var libs = std.ArrayList(*std.build.LibExeObjStep).init(sdk.b.allocator);
    defer libs.deinit();

    const build_options = BuildOptionStep.create(sdk.b);
    build_options.add([]const u8, "app_name", app_config.app_name);
    build_options.add(u16, "android_sdk_version", app_config.target_sdk_version orelse sdk.versions.android_sdk_version);
    build_options.add(bool, "fullscreen", app_config.fullscreen);

    const sign_step = sdk.signApk(apk_file, key_store);

    inline for (std.meta.fields(AppTargetConfig)) |fld| {
        const target_name = @field(Target, fld.name);
        if (@field(targets, fld.name)) {
            const library = sdk.compileAppLibrary(
                src_file,
                app_config,
                mode,
                target_name,
                //   build_options.getPackage("build_options"),
            );
            libs.append(library.app_step) catch unreachable;

            const so_dir = switch (target_name) {
                .aarch64 => "lib/arm64-v8a/",
                .arm => "lib/armeabi/",
                .x86_64 => "lib/x86_64/",
                .x86 => "lib/x86/",
            };

            {
                const copy_to_zip = CopyToZipStep.create(sdk, apk_file, so_dir, library.app_step.getOutputSource());
                copy_to_zip.step.dependOn(&make_unsigned_apk.step); // enforces creation of APK before the execution
                sign_step.dependOn(&copy_to_zip.step);
            }

            for (library.libraries) |lib| {
                const copy_to_zip = CopyToZipStep.create(sdk, apk_file, so_dir, .{ .path = lib });
                copy_to_zip.step.dependOn(&make_unsigned_apk.step); // enforces creation of APK before the execution
                sign_step.dependOn(&copy_to_zip.step);
            }
        }
    }

    // const compress_step = compressApk(b, android_config, apk_file, "zig-out/demo.packed.apk");
    // compress_step.dependOn(sign_step);

    return CreateAppStep{
        .sdk = sdk,
        .first_step = &make_unsigned_apk.step,
        .final_step = sign_step,
        .libraries = libs.toOwnedSlice(),
        .build_options = build_options,
        .package_name = sdk.b.dupe(app_config.package_name),
        .apk_file = (std.build.FileSource{ .path = apk_file }).dupe(sdk.b),
    };
}

const CreateResourceDirectory = struct {
    const Self = @This();
    builder: *std.build.Builder,
    step: std.build.Step,

    resources: std.ArrayList(Resource),
    directory: std.build.GeneratedFile,

    pub fn create(b: *std.build.Builder) *Self {
        const self = b.allocator.create(Self) catch @panic("out of memory");
        self.* = Self{
            .builder = b,
            .step = Step.init(.custom, "populate resource directory", b.allocator, CreateResourceDirectory.make),
            .directory = .{ .step = &self.step },
            .resources = std.ArrayList(Resource).init(b.allocator),
        };
        return self;
    }

    pub fn add(self: *Self, resource: Resource) void {
        self.resources.append(Resource{
            .path = self.builder.dupe(resource.path),
            .content = resource.content.dupe(self.builder),
        }) catch @panic("out of memory");
        resource.content.addStepDependencies(&self.step);
    }

    pub fn getOutputDirectory(self: *Self) std.build.FileSource {
        return .{ .generated = &self.directory };
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(Self, "step", step);

        // if (std.fs.path.dirname(strings_xml)) |dir| {
        //     std.fs.cwd().makePath(dir) catch unreachable;
        // }

        var cacher = createCacheBuilder(self.builder);
        for (self.resources.items) |res| {
            cacher.addBytes(res.path);
            try cacher.addFile(res.content);
        }

        const root = try cacher.createAndGetDir();
        for (self.resources.items) |res| {
            if (std.fs.path.dirname(res.path)) |folder| {
                try root.dir.makePath(folder);
            }

            const src_path = res.content.getPath(self.builder);
            try std.fs.Dir.copyFile(
                std.fs.cwd(),
                src_path,
                root.dir,
                res.path,
                .{},
            );
        }

        self.directory.path = root.path;
    }
};

const CopyToZipStep = struct {
    step: Step,
    sdk: *Sdk,
    target_dir: []const u8,
    input_file: std.build.FileSource,
    apk_file: []const u8,

    fn create(sdk: *Sdk, apk_file: []const u8, target_dir: []const u8, input_file: std.build.FileSource) *CopyToZipStep {
        std.debug.assert(target_dir[target_dir.len - 1] == '/');
        const self = sdk.b.allocator.create(CopyToZipStep) catch unreachable;
        self.* = CopyToZipStep{
            .step = Step.init(.custom, "copy to zip", sdk.b.allocator, make),
            .target_dir = target_dir,
            .input_file = input_file,
            .sdk = sdk,
            .apk_file = sdk.b.pathFromRoot(apk_file),
        };
        self.step.dependOn(&sdk.host_tools.zip_add.step);
        input_file.addStepDependencies(&self.step);
        return self;
    }

    // id: Id, name: []const u8, allocator: *Allocator, makeFn: fn (*Step) anyerror!void

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(CopyToZipStep, "step", step);

        const output_path = self.input_file.getPath(self.sdk.b);

        var zip_name = std.mem.concat(self.sdk.b.allocator, u8, &[_][]const u8{
            self.target_dir,
            std.fs.path.basename(output_path),
        }) catch unreachable;

        const args = [_][]const u8{
            self.sdk.host_tools.zip_add.getOutputSource().getPath(self.sdk.b),
            self.apk_file,
            output_path,
            zip_name,
        };

        _ = try self.sdk.b.execFromStep(&args, &self.step);
    }
};

/// Compiles a single .so file for the given platform.
/// Note that this function assumes your build script only uses a single `android_config`!
const AppLibrary = struct {
    app_step: *std.build.LibExeObjStep,
    libraries: []const []const u8,
};
pub fn compileAppLibrary(
    sdk: Sdk,
    src_file: []const u8,
    app_config: AppConfig,
    mode: std.builtin.Mode,
    target: Target,
    // build_options: std.build.Pkg,
) AppLibrary {
    switch (target) {
        .arm => @panic("compiling android apps to arm not supported right now. see: https://github.com/ziglang/zig/issues/8885"),
        .x86 => @panic("compiling android apps to x86 not supported right now. see https://github.com/ziglang/zig/issues/7935"),
        else => {},
    }

    const ndk_root = sdk.b.pathFromRoot(sdk.folders.android_ndk_root);

    const exe = sdk.b.addSharedLibrary(app_config.app_name, src_file, .unversioned);
    exe.force_pic = true;
    exe.link_function_sections = true;
    exe.bundle_compiler_rt = true;
    exe.strip = (mode == .ReleaseSmall);

    exe.defineCMacro("ANDROID", null);

    const include_dir = std.fs.path.resolve(sdk.b.allocator, &[_][]const u8{ ndk_root, "sysroot/usr/include" }) catch unreachable;
    exe.addIncludeDir(include_dir);

    exe.linkLibC();
    for (app_libs) |lib| {
        exe.linkSystemLibraryName(lib);
    }

    exe.setBuildMode(mode);

    const TargetConfig = struct {
        lib_dir: []const u8,
        include_dir: []const u8,
        out_dir: []const u8,
        vrapi_dir: []const u8,
        target: std.zig.CrossTarget,
    };

    const config: TargetConfig = switch (target) {
        .aarch64 => TargetConfig{
            .lib_dir = "arch-arm64/usr/lib",
            .include_dir = "aarch64-linux-android",
            .out_dir = "arm64-v8a",
            .vrapi_dir = "quest_sdk/VrApi/Libs/Android/arm64-v8a",
            .target = zig_targets.aarch64,
        },
        .arm => TargetConfig{
            .lib_dir = "arch-arm/usr/lib",
            .include_dir = "arm-linux-androideabi",
            .out_dir = "armeabi",
            .vrapi_dir = "quest_sdk/VrApi/Libs/Android/armeabi-v7a",
            .target = zig_targets.arm,
        },
        .x86 => TargetConfig{
            .lib_dir = "arch-x86/usr/lib",
            .include_dir = "i686-linux-android",
            .out_dir = "x86",
            .vrapi_dir = @panic("VrApi not built for x86, cannot link this platform"),
            .target = zig_targets.x86,
        },
        .x86_64 => TargetConfig{
            .lib_dir = "arch-x86_64/usr/lib64",
            .include_dir = "x86_64-linux-android",
            .out_dir = "x86_64",
            .vrapi_dir = @panic("VrApi not built for x86_64, cannot link this platform"),
            .target = zig_targets.x86_64,
        },
    };

    const lib_dir_root = sdk.b.fmt("{s}/platforms/android-{d}", .{
        ndk_root,
        sdk.versions.android_sdk_version,
    });

    const libc_path = std.fs.path.resolve(sdk.b.allocator, &[_][]const u8{
        sdk.b.cache_root,
        "android-libc",
        sdk.b.fmt("android-{d}-{s}.conf", .{ sdk.versions.android_sdk_version, config.out_dir }),
    }) catch unreachable;

    const lib_dir = std.fs.path.resolve(sdk.b.allocator, &[_][]const u8{ lib_dir_root, config.lib_dir }) catch unreachable;

    exe.setTarget(config.target);
    exe.addLibPath(lib_dir);
    exe.addIncludeDir(std.fs.path.resolve(sdk.b.allocator, &[_][]const u8{ include_dir, config.include_dir }) catch unreachable);

    // write libc file:
    const libc_file_step = CreateLibCFileStep.create(sdk.b, libc_path, include_dir, include_dir, lib_dir);
    exe.libc_file = std.build.FileSource{ .generated = &libc_file_step.path };
    exe.step.dependOn(&libc_file_step.step);

    const vrapi_version = if (mode == .Debug) "Debug" else "Release";
    const vrapi_lib_path = std.fs.path.join(sdk.b.allocator, &[_][]const u8{ config.vrapi_dir, vrapi_version }) catch unreachable;
    exe.addLibPath(vrapi_lib_path);
    exe.linkSystemLibraryName("vrapi");

    const libraries = sdk.b.allocator.alloc([]const u8, 1) catch unreachable;
    const vrapi_lib = std.fs.path.join(sdk.b.allocator, &[_][]const u8{ vrapi_lib_path, "libvrapi.so" }) catch unreachable;
    libraries[0] = vrapi_lib;

    return .{
        .app_step = exe,
        .libraries = libraries,
    };
}

pub fn compressApk(sdk: Sdk, input_apk_file: []const u8, output_apk_file: []const u8) *Step {
    const temp_folder = sdk.b.pathFromRoot("zig-cache/apk-compress-folder");

    const mkdir_cmd = sdk.b.addSystemCommand(&[_][]const u8{
        sdk.system_tools.mkdir,
        temp_folder,
    });

    const unpack_apk = sdk.b.addSystemCommand(&[_][]const u8{
        "unzip",
        "-o",
        sdk.builder.pathFromRoot(input_apk_file),
        "-d",
        temp_folder,
    });
    unpack_apk.step.dependOn(&mkdir_cmd.step);

    const repack_apk = sdk.b.addSystemCommand(&[_][]const u8{
        "zip",
        "-D9r",
        sdk.builder.pathFromRoot(output_apk_file),
        ".",
    });
    repack_apk.cwd = temp_folder;
    repack_apk.step.dependOn(&unpack_apk.step);

    const rmdir_cmd = sdk.b.addSystemCommand(&[_][]const u8{
        sdk.system_tools.rm,
        "-rf",
        temp_folder,
    });
    rmdir_cmd.step.dependOn(&repack_apk.step);
    return &rmdir_cmd.step;
}

pub fn signApk(sdk: Sdk, apk_file: []const u8, key_store: KeyStore) *Step {
    const sign_apk = sdk.b.addSystemCommand(&[_][]const u8{
        sdk.system_tools.jarsigner,
        "-sigalg",
        "SHA1withRSA",
        "-digestalg",
        "SHA1",
        "-verbose",
        "-keystore",
        key_store.file,
        "-storepass",
        key_store.password,
        sdk.b.pathFromRoot(apk_file),
        key_store.alias,
    });
    return &sign_apk.step;
}

pub fn alignApk(sdk: Sdk, input_apk_file: []const u8, output_apk_file: []const u8) *Step {
    const step = sdk.b.addSystemCommand(&[_][]const u8{
        sdk.system_tools.zipalign,
        "-v",
        "4",
        sdk.builder.pathFromRoot(input_apk_file),
        sdk.builder.pathFromRoot(output_apk_file),
    });
    return &step.step;
}

pub fn installApp(sdk: Sdk, apk_file: std.build.FileSource) *Step {
    const step = sdk.b.addSystemCommand(&[_][]const u8{ sdk.system_tools.adb, "install" });
    step.addFileSourceArg(apk_file);
    return &step.step;
}

pub fn startApp(sdk: Sdk, package_name: []const u8) *Step {
    const step = sdk.b.addSystemCommand(&[_][]const u8{
        sdk.system_tools.adb,
        "shell",
        "am",
        "start",
        "-n",
        sdk.b.fmt("{s}/android.app.NativeActivity", .{package_name}),
    });
    return &step.step;
}

/// Configuration for a signing key.
pub const KeyConfig = struct {
    pub const Algorithm = enum { RSA };
    key_algorithm: Algorithm = .RSA,
    key_size: u32 = 2048, // bits
    validity: u32 = 10_000, // days
    distinguished_name: []const u8 = "CN=example.com, OU=ID, O=Example, L=Doe, S=John, C=GB",
};
/// A build step that initializes a new key store from the given configuration.
/// `android_config.key_store` must be non-`null` as it is used to initialize the key store.
pub fn initKeystore(sdk: Sdk, key_store: KeyStore, key_config: KeyConfig) *Step {
    const step = sdk.b.addSystemCommand(&[_][]const u8{
        sdk.system_tools.keytool,
        "-genkey",
        "-v",
        "-keystore",
        key_store.file,
        "-alias",
        key_store.alias,
        "-keyalg",
        @tagName(key_config.key_algorithm),
        "-keysize",
        sdk.b.fmt("{d}", .{key_config.key_size}),
        "-validity",
        sdk.b.fmt("{d}", .{key_config.validity}),
        "-storepass",
        key_store.password,
        "-keypass",
        key_store.password,
        "-dname",
        key_config.distinguished_name,
    });
    return &step.step;
}

const Builder = std.build.Builder;
const Step = std.build.Step;

const android_os = .linux;
const android_abi = .android;

const zig_targets = struct {
    const aarch64 = std.zig.CrossTarget{
        .cpu_arch = .aarch64,
        .os_tag = android_os,
        .abi = android_abi,
        .cpu_model = .baseline,
        .cpu_features_add = std.Target.aarch64.featureSet(&.{.v8a}),
    };

    const arm = std.zig.CrossTarget{
        .cpu_arch = .arm,
        .os_tag = android_os,
        .abi = android_abi,
        .cpu_model = .baseline,
        .cpu_features_add = std.Target.arm.featureSet(&.{.v7a}),
    };

    const x86 = std.zig.CrossTarget{
        .cpu_arch = .i386,
        .os_tag = android_os,
        .abi = android_abi,
        .cpu_model = .baseline,
    };

    const x86_64 = std.zig.CrossTarget{
        .cpu_arch = .x86_64,
        .os_tag = android_os,
        .abi = android_abi,
        .cpu_model = .baseline,
    };
};

const app_libs = [_][]const u8{
    "GLESv2", "EGL", "android", "log",
};

const BuildOptionStep = struct {
    const Self = @This();

    step: Step,
    builder: *std.build.Builder,
    file_content: std.ArrayList(u8),
    package_file: std.build.GeneratedFile,

    pub fn create(b: *Builder) *Self {
        const options = b.allocator.create(Self) catch @panic("out of memory");

        options.* = Self{
            .builder = b,
            .step = Step.init(.custom, "render build options", b.allocator, make),
            .file_content = std.ArrayList(u8).init(b.allocator),
            .package_file = std.build.GeneratedFile{ .step = &options.step },
        };

        return options;
    }

    pub fn getPackage(self: *Self, name: []const u8) std.build.Pkg {
        return self.builder.dupePkg(std.build.Pkg{
            .name = name,
            .path = .{ .generated = &self.package_file },
        });
    }

    pub fn add(self: *Self, comptime T: type, name: []const u8, value: T) void {
        const out = self.file_content.writer();
        switch (T) {
            []const []const u8 => {
                out.print("pub const {}: []const []const u8 = &[_][]const u8{{\n", .{std.zig.fmtId(name)}) catch unreachable;
                for (value) |slice| {
                    out.print("    \"{}\",\n", .{std.zig.fmtEscapes(slice)}) catch unreachable;
                }
                out.writeAll("};\n") catch unreachable;
                return;
            },
            [:0]const u8 => {
                out.print("pub const {}: [:0]const u8 = \"{}\";\n", .{ std.zig.fmtId(name), std.zig.fmtEscapes(value) }) catch unreachable;
                return;
            },
            []const u8 => {
                out.print("pub const {}: []const u8 = \"{}\";\n", .{ std.zig.fmtId(name), std.zig.fmtEscapes(value) }) catch unreachable;
                return;
            },
            ?[:0]const u8 => {
                out.print("pub const {}: ?[:0]const u8 = ", .{std.zig.fmtId(name)}) catch unreachable;
                if (value) |payload| {
                    out.print("\"{}\";\n", .{std.zig.fmtEscapes(payload)}) catch unreachable;
                } else {
                    out.writeAll("null;\n") catch unreachable;
                }
                return;
            },
            ?[]const u8 => {
                out.print("pub const {}: ?[]const u8 = ", .{std.zig.fmtId(name)}) catch unreachable;
                if (value) |payload| {
                    out.print("\"{}\";\n", .{std.zig.fmtEscapes(payload)}) catch unreachable;
                } else {
                    out.writeAll("null;\n") catch unreachable;
                }
                return;
            },
            std.builtin.Version => {
                out.print(
                    \\pub const {}: @import("std").builtin.Version = .{{
                    \\    .major = {d},
                    \\    .minor = {d},
                    \\    .patch = {d},
                    \\}};
                    \\
                , .{
                    std.zig.fmtId(name),

                    value.major,
                    value.minor,
                    value.patch,
                }) catch unreachable;
            },
            std.SemanticVersion => {
                out.print(
                    \\pub const {}: @import("std").SemanticVersion = .{{
                    \\    .major = {d},
                    \\    .minor = {d},
                    \\    .patch = {d},
                    \\
                , .{
                    std.zig.fmtId(name),

                    value.major,
                    value.minor,
                    value.patch,
                }) catch unreachable;
                if (value.pre) |some| {
                    out.print("    .pre = \"{}\",\n", .{std.zig.fmtEscapes(some)}) catch unreachable;
                }
                if (value.build) |some| {
                    out.print("    .build = \"{}\",\n", .{std.zig.fmtEscapes(some)}) catch unreachable;
                }
                out.writeAll("};\n") catch unreachable;
                return;
            },
            else => {},
        }
        switch (@typeInfo(T)) {
            .Enum => |enum_info| {
                out.print("pub const {} = enum {{\n", .{std.zig.fmtId(@typeName(T))}) catch unreachable;
                inline for (enum_info.fields) |field| {
                    out.print("    {},\n", .{std.zig.fmtId(field.name)}) catch unreachable;
                }
                out.writeAll("};\n") catch unreachable;
            },
            else => {},
        }
        out.print("pub const {}: {s} = {};\n", .{ std.zig.fmtId(name), @typeName(T), value }) catch unreachable;
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(Self, "step", step);

        var cacher = createCacheBuilder(self.builder);
        cacher.addBytes(self.file_content.items);

        const root_path = try cacher.createAndGetPath();

        self.package_file.path = try std.fs.path.join(self.builder.allocator, &[_][]const u8{
            root_path,
            "build_options.zig",
        });

        try std.fs.cwd().writeFile(self.package_file.path.?, self.file_content.items);
    }
};

fn createCacheBuilder(b: *std.build.Builder) CacheBuilder {
    return CacheBuilder.init(b, "android-sdk");
}

const CacheBuilder = struct {
    const Self = @This();

    builder: *std.build.Builder,
    hasher: std.crypto.hash.Sha1,
    subdir: ?[]const u8,

    pub fn init(builder: *std.build.Builder, subdir: ?[]const u8) Self {
        return Self{
            .builder = builder,
            .hasher = std.crypto.hash.Sha1.init(.{}),
            .subdir = if (subdir) |s|
                builder.dupe(s)
            else
                null,
        };
    }

    pub fn addBytes(self: *Self, bytes: []const u8) void {
        self.hasher.update(bytes);
    }

    pub fn addFile(self: *Self, file: std.build.FileSource) !void {
        const path = file.getPath(self.builder);

        const data = try std.fs.cwd().readFileAlloc(self.builder.allocator, path, 1 << 32); // 4 GB
        defer self.builder.allocator.free(data);

        self.addBytes(data);
    }

    fn createPath(self: *Self) ![]const u8 {
        var hash: [20]u8 = undefined;
        self.hasher.final(&hash);

        const path = if (self.subdir) |subdir|
            try std.fmt.allocPrint(
                self.builder.allocator,
                "{s}/{s}/o/{}",
                .{
                    self.builder.cache_root,
                    subdir,
                    std.fmt.fmtSliceHexLower(&hash),
                },
            )
        else
            try std.fmt.allocPrint(
                self.builder.allocator,
                "{s}/o/{}",
                .{
                    self.builder.cache_root,
                    std.fmt.fmtSliceHexLower(&hash),
                },
            );

        return path;
    }

    pub const DirAndPath = struct {
        dir: std.fs.Dir,
        path: []const u8,
    };
    pub fn createAndGetDir(self: *Self) !DirAndPath {
        const path = try self.createPath();
        return DirAndPath{
            .path = path,
            .dir = try std.fs.cwd().makeOpenPath(path, .{}),
        };
    }

    pub fn createAndGetPath(self: *Self) ![]const u8 {
        const path = try self.createPath();
        try std.fs.cwd().makePath(path);
        return path;
    }
};

// Can't use a WriteFileStep for this because we need to generate directories.
const CreateLibCFileStep = struct {
    step: std.build.Step,
    path: std.build.GeneratedFile,
    include_dir: []const u8,
    sys_include_dir: []const u8,
    crt_dir: []const u8,

    pub fn create(
        b: *std.build.Builder,
        path: []const u8,
        include_dir: []const u8,
        sys_include_dir: []const u8,
        crt_dir: []const u8,
    ) *CreateLibCFileStep {
        const self = b.allocator.create(CreateLibCFileStep) catch unreachable;
        self.* = .{
            .step = std.build.Step.init(.custom, b.fmt("Create libc file {s}", .{path}), b.allocator, make),
            .path = .{ .path = path, .step = &self.step },
            .include_dir = include_dir,
            .sys_include_dir = sys_include_dir,
            .crt_dir = crt_dir,
        };
        return self;
    }

    fn make(step: *Step) anyerror!void {
        const self = @fieldParentPtr(@This(), "step", step);
        const path = self.path.path.?;

        if (std.fs.path.dirname(path)) |dir| {
            try std.fs.cwd().makePath(dir);
        }

        var f = try std.fs.cwd().createFile(path, .{});
        defer f.close();

        var writer = f.writer();

        try writer.print("include_dir={s}\n", .{self.include_dir});
        try writer.print("sys_include_dir={s}\n", .{self.sys_include_dir});
        try writer.print("crt_dir={s}\n", .{self.crt_dir});
        try writer.writeAll("msvc_lib_dir=\n");
        try writer.writeAll("kernel32_lib_dir=\n");
        try writer.writeAll("gcc_dir=\n");
    }
};
