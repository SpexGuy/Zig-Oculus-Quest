//! Copyright (c) Facebook Technologies, LLC and its affiliates. All rights reserved.

const android = @import("android-support.zig");
const std = @import("std");

pub const PRODUCT_VERSION = 1;
pub const MAJOR_VERSION = 1;
pub const MINOR_VERSION = 50;
pub const PATCH_VERSION = 0;
pub const BUILD_VERSION = 314801631;
pub const BUILD_DESCRIPTION = "Development";
pub const DRIVER_VERSION = 314801631;

pub const getVersionString = vrapi_GetVersionString;
extern fn vrapi_GetVersionString() ?[*:0]const u8;

pub const getTimeInSeconds = vrapi_GetTimeInSeconds;
extern fn vrapi_GetTimeInSeconds() f64;

pub fn initialize(initParms: InitParms) !void {
    const rc = vrapi_Initialize(&initParms);
    if (rc == .success) return;
    switch (rc) {
        .success => unreachable,
        .permissions_error => return error.OVR_Initialize_PermissionsError,
        .already_initialized => return error.OVR_Initialize_AlreadyInitialized,
        .service_connection_failed => return error.OVR_Initialize_ServiceConnectionFailed,
        .device_not_supported => return error.OVR_Initialize_DeviceNotSupported,
        .unknown_error => return error.OVR_Initialize_UnknownError,
        _ => return error.OVR_Initialize_UnknownError,
    }
}
extern fn vrapi_Initialize(initParms: *const InitParms) InitializeStatus;

pub const shutdown = vrapi_Shutdown;
extern fn vrapi_Shutdown() void;

pub const pollEvent = vrapi_PollEvent;
extern fn vrapi_PollEvent(event: *EventHeader) Result;

pub const Java = extern struct {
    Vm: *android.JavaVM,
    Env: *android.JNIEnv,
    ActivityObject: android.jobject,

    pub const Property = enum (u32) {
        foveation_level = 15,
        eat_native_gamepad_events = 20,
        active_input_device_id = 24,
        device_emulation_mode = 29,
        dynamic_foveation_enabled = 30,
        _,
    };

    pub fn setPropertyInt(java: Java, propType: Property, intVal: c_int) void {
        vrapi_SetPropertyInt(&java, propType, intVal);
    }
    pub fn setPropertyFloat(java: Java, propType: Property, floatVal: f32) void {
        vrapi_SetPropertyFloat(&java, propType, floatVal);
    }
    pub fn getPropertyInt(java: Java, propType: Property) ?c_int {
        var result: c_int = undefined;
        if (vrapi_GetPropertyInt(&java, propType, &result)) return result;
        return null;
    }

    pub const SystemProperty = enum (u32) {
        device_type = 0,
        max_fullspeed_framebuffer_samples = 1,
        display_pixels_wide = 2,
        display_pixels_high = 3,
        display_refresh_rate = 4,
        suggested_eye_texture_width = 5,
        suggested_eye_texture_height = 6,
        suggested_eye_fov_degrees_x = 7,
        suggested_eye_fov_degrees_y = 8,
        device_region = 10,
        dominant_hand = 15,
        has_orientation_tracking = 16,
        has_position_tracking = 17,
        num_supported_display_refresh_rates = 64,
        supported_display_refresh_rates = 65,
        num_supported_swapchain_formats = 66,
        supported_swapchain_formats = 67,
        foveation_available = 130,
        _,
    };

    pub fn getSystemPropertyInt(java: Java, propType: SystemProperty) c_int {
        return vrapi_GetSystemPropertyInt(&java, propType);
    }
    pub fn getSystemPropertyFloat(java: Java, propType: SystemProperty) f32 {
        return vrapi_GetSystemPropertyFloat(&java, propType);
    }
    pub fn getSystemPropertyFloatArray(java: Java, propType: SystemProperty, buffer: []f32) []f32 {
        const len = vrapi_GetSystemPropertyFloatArray(&java, propType, buffer.ptr, @intCast(c_int, buffer.len));
        return buffer[0..@intCast(usize, len)];
    }
    pub fn getSystemPropertyInt64Array(java: Java, propType: SystemProperty, buffer: []i64) []i64 {
        const len = vrapi_GetSystemPropertyInt64Array(&java, propType, buffer.ptr, @intCast(c_int, buffer.len));
        return buffer[0..@intCast(usize, len)];
    }
    pub fn getSystemPropertyString(java: Java, propType: SystemProperty) ?[*:0]const u8 {
        return vrapi_GetSystemPropertyString(&java, propType);
    }

    pub const SystemStatus = enum (u32) {
        mounted = 1,
        throttled = 2,
        render_latency_milliseconds = 5,
        timewarp_latency_milliseconds = 6,
        scanout_latency_milliseconds = 7,
        app_frames_per_second = 8,
        screen_tears_per_second = 9,
        early_frames_per_second = 10,
        stale_frames_per_second = 11,
        recenter_count = 13,
        user_recenter_count = 15,
        front_buffer_srgb = 130,
        screen_capture_running = 131,
        _,
    };

    pub fn getSystemStatusInt(java: Java, statusType: SystemStatus) c_int {
        return vrapi_GetSystemStatusInt(&java, statusType);
    }
    pub fn getSystemStatusFloat(java: Java, statusType: SystemStatus) f32 {
        return vrapi_GetSystemStatusFloat(&java, statusType);
    }

    pub const SystemUIType = enum (u32) {
        confirm_quit_menu = 1,
        _,
    };

    pub fn showSystemUI(java: Java, @"type": SystemUIType) bool {
        return vrapi_ShowSystemUI(&java, @"type");
    }

    extern fn vrapi_SetPropertyInt(java: *const Java, propType: Property, intVal: c_int) void;
    extern fn vrapi_SetPropertyFloat(java: *const Java, propType: Property, floatVal: f32) void;
    extern fn vrapi_GetPropertyInt(java: *const Java, propType: Property, intVal: *c_int) bool;
    extern fn vrapi_GetSystemPropertyInt(java: *const Java, propType: SystemProperty) c_int;
    extern fn vrapi_GetSystemPropertyFloat(java: *const Java, propType: SystemProperty) f32;
    extern fn vrapi_GetSystemPropertyFloatArray(java: *const Java, propType: SystemProperty, values: ?[*]f32, numArrayValues: c_int) c_int;
    extern fn vrapi_GetSystemPropertyInt64Array(java: *const Java, propType: SystemProperty, values: ?[*]i64, numArrayValues: c_int) c_int;
    extern fn vrapi_GetSystemPropertyString(java: *const Java, propType: SystemProperty) ?[*:0]const u8;
    extern fn vrapi_GetSystemStatusInt(java: *const Java, statusType: SystemStatus) c_int;
    extern fn vrapi_GetSystemStatusFloat(java: *const Java, statusType: SystemStatus) f32;
    extern fn vrapi_ShowSystemUI(java: *const Java, @"type": SystemUIType) bool;
};

pub const Result = c_int;
pub const Success: c_int = 0;
pub const Success_BoundaryInvalid: c_int = 1001;
pub const Success_EventUnavailable: c_int = 1002;
pub const Success_Skipped: c_int = 1003;
pub const SuccessResult = c_uint;
pub const Error_MemoryAllocationFailure: c_int = -1000;
pub const Error_NotInitialized: c_int = -1004;
pub const Error_InvalidParameter: c_int = -1005;
pub const Error_DeviceUnavailable: c_int = -1010;
pub const Error_InvalidOperation: c_int = -1015;
pub const Error_UnsupportedDeviceType: c_int = -1050;
pub const Error_NoDevice: c_int = -1051;
pub const Error_NotImplemented: c_int = -1052;
pub const Error_NotReady: c_int = -1053;
pub const Error_Unavailable: c_int = -1054;
pub const ErrorResult = c_int;

pub const Vector2f = extern struct {
    x: f32,
    y: f32,

    pub const zero = Vector2f{ .x = 0, .y = 0 };

    pub fn init(x: f32, y: f32) Vector2f {
        return .{ .x = x, .y = y };
    }

    pub fn extended(self: @This(), z: f32) Vector3f {
        return Vector3f.init(self.x, self.y, z);
    }

    pub fn extended2(self: @This(), z: f32, w: f32) Vector4f {
        return Vector4f.init(self.x, self.y, z, w);
    }

    pub fn projected(self: @This()) Vector4f {
        return self.extend2(0, 1);
    }
};
pub const Vector3f = extern struct {
    x: f32,
    y: f32,
    z: f32,

    pub const zero = Vector3f{ .x = 0, .y = 0, .z = 0 };

    pub fn init(x: f32, y: f32, z: f32) Vector3f {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn extended(self: @This(), w: f32) Vector4f {
        return Vector4f.init(self.x, self.y, self.z, w);
    }

    pub fn flattened(self: @This()) Vector2f {
        return Vector2f.init(self.x, self.y);
    }

    pub fn projected(self: @This()) Vector4f {
        return self.extended(1);
    }

    pub fn rotateAboutPivot(point: Vector3f, rotation: Quatf, pivot: Vector3f) Vector3f {
        const rotor = Matrix4f.createTranslation(pivot.x, pivot.y, pivot.z)
            .multiply(Matrix4f.createFromQuaternion(rotation))
            .multiply(Matrix4f.createTranslation(-pivot.x, -pivot.y, -pivot.z));
        return rotor.transform(point.projected()).position();
    }
};
pub const Vector4f = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub const zero = Vector4f{ .x = 0, .y = 0, .z = 0, .w = 0 };

    pub fn init(x: f32, y: f32, z: f32, w: f32) Vector4f {
        return .{ .x = x, .y = y, .z = z, .w = w };
    }

    pub fn perspective(self: @This()) Vector4f {
        const mult = 1.0 / self.w;
        const nx = self.x * mult;
        const ny = self.y * mult;
        const nz = self.z * mult;
        return Vector4f.init(nx, ny, nz, 1);
    }

    pub fn position(self: @This()) Vector3f {
        return Vector3f.init(self.x, self.y, self.z);
    }

    pub fn positionPerspective(self: @This()) Vector3f {
        const mult = 1.0 / self.w;
        const nx = self.x * mult;
        const ny = self.y * mult;
        const nz = self.z * mult;
        return Vector3f.init(nx, ny, nz);
    }

    pub fn flattened(self: @This()) Vector2f {
        return Vector2f.init(self.x, self.y);
    }

    pub fn flattenedPerspective(self: @This()) Vector2f {
        const mult = 1.0 / self.w;
        const nx = self.x * mult;
        const ny = self.y * mult;
        return Vector2f.init(nx, ny);
    }
};
pub const Vector4s = extern struct {
    x: i16,
    y: i16,
    z: i16,
    w: i16,

    pub const zero = Vector4s{ .x = 0, .y = 0, .z = 0, .w = 0 };
};
pub const Quatf = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub const identity = Quatf{ .x = 0, .y = 0, .z = 0, .w = 1 };
};
pub const Matrix4f = extern struct {
    M: [4][4]f32,

    pub const identity = Matrix4f{ .M = .{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    } };

    pub const identity_3x3 = Matrix4f{ .M = .{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 0 },
    } };

    pub const zero = Matrix4f{ .M = .{
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
        .{ 0, 0, 0, 0 },
    } };

    pub fn multiply(a: Matrix4f, b: Matrix4f) Matrix4f {
        var out: Matrix4f = undefined;
        out.M[0][0] = (((a.M[0][0] * b.M[0][0]) + (a.M[0][1] * b.M[1][0])) + (a.M[0][2] * b.M[2][0])) + (a.M[0][3] * b.M[3][0]);
        out.M[1][0] = (((a.M[1][0] * b.M[0][0]) + (a.M[1][1] * b.M[1][0])) + (a.M[1][2] * b.M[2][0])) + (a.M[1][3] * b.M[3][0]);
        out.M[2][0] = (((a.M[2][0] * b.M[0][0]) + (a.M[2][1] * b.M[1][0])) + (a.M[2][2] * b.M[2][0])) + (a.M[2][3] * b.M[3][0]);
        out.M[3][0] = (((a.M[3][0] * b.M[0][0]) + (a.M[3][1] * b.M[1][0])) + (a.M[3][2] * b.M[2][0])) + (a.M[3][3] * b.M[3][0]);
        out.M[0][1] = (((a.M[0][0] * b.M[0][1]) + (a.M[0][1] * b.M[1][1])) + (a.M[0][2] * b.M[2][1])) + (a.M[0][3] * b.M[3][1]);
        out.M[1][1] = (((a.M[1][0] * b.M[0][1]) + (a.M[1][1] * b.M[1][1])) + (a.M[1][2] * b.M[2][1])) + (a.M[1][3] * b.M[3][1]);
        out.M[2][1] = (((a.M[2][0] * b.M[0][1]) + (a.M[2][1] * b.M[1][1])) + (a.M[2][2] * b.M[2][1])) + (a.M[2][3] * b.M[3][1]);
        out.M[3][1] = (((a.M[3][0] * b.M[0][1]) + (a.M[3][1] * b.M[1][1])) + (a.M[3][2] * b.M[2][1])) + (a.M[3][3] * b.M[3][1]);
        out.M[0][2] = (((a.M[0][0] * b.M[0][2]) + (a.M[0][1] * b.M[1][2])) + (a.M[0][2] * b.M[2][2])) + (a.M[0][3] * b.M[3][2]);
        out.M[1][2] = (((a.M[1][0] * b.M[0][2]) + (a.M[1][1] * b.M[1][2])) + (a.M[1][2] * b.M[2][2])) + (a.M[1][3] * b.M[3][2]);
        out.M[2][2] = (((a.M[2][0] * b.M[0][2]) + (a.M[2][1] * b.M[1][2])) + (a.M[2][2] * b.M[2][2])) + (a.M[2][3] * b.M[3][2]);
        out.M[3][2] = (((a.M[3][0] * b.M[0][2]) + (a.M[3][1] * b.M[1][2])) + (a.M[3][2] * b.M[2][2])) + (a.M[3][3] * b.M[3][2]);
        out.M[0][3] = (((a.M[0][0] * b.M[0][3]) + (a.M[0][1] * b.M[1][3])) + (a.M[0][2] * b.M[2][3])) + (a.M[0][3] * b.M[3][3]);
        out.M[1][3] = (((a.M[1][0] * b.M[0][3]) + (a.M[1][1] * b.M[1][3])) + (a.M[1][2] * b.M[2][3])) + (a.M[1][3] * b.M[3][3]);
        out.M[2][3] = (((a.M[2][0] * b.M[0][3]) + (a.M[2][1] * b.M[1][3])) + (a.M[2][2] * b.M[2][3])) + (a.M[2][3] * b.M[3][3]);
        out.M[3][3] = (((a.M[3][0] * b.M[0][3]) + (a.M[3][1] * b.M[1][3])) + (a.M[3][2] * b.M[2][3])) + (a.M[3][3] * b.M[3][3]);
        return out;
    }
    pub fn transpose(a: Matrix4f) Matrix4f {
        var out: Matrix4f = undefined;
        out.M[0][0] = a.M[0][0];
        out.M[0][1] = a.M[1][0];
        out.M[0][2] = a.M[2][0];
        out.M[0][3] = a.M[3][0];
        out.M[1][0] = a.M[0][1];
        out.M[1][1] = a.M[1][1];
        out.M[1][2] = a.M[2][1];
        out.M[1][3] = a.M[3][1];
        out.M[2][0] = a.M[0][2];
        out.M[2][1] = a.M[1][2];
        out.M[2][2] = a.M[2][2];
        out.M[2][3] = a.M[3][2];
        out.M[3][0] = a.M[0][3];
        out.M[3][1] = a.M[1][3];
        out.M[3][2] = a.M[2][3];
        out.M[3][3] = a.M[3][3];
        return out;
    }
    pub fn minor(m: Matrix4f, r0: u32, r1: u32, r2: u32, c0: u32, c1: u32, c2: u32) f32 {
        return m.M[r0][c0] * (m.M[r1][c1] * m.M[r2][c2] - m.M[r2][c1] * m.M[r1][c2])
            - m.M[r0][c1] * (m.M[r1][c0] * m.M[r2][c2] - m.M[r2][c0] * m.M[r1][c2])
            + m.M[r0][c2] * (m.M[r1][c0] * m.M[r2][c1] - m.M[r2][c0] * m.M[r1][c1]);
    }
    pub fn inverse(m: Matrix4f) Matrix4f {
        const rcpDet: f32 = 1.0 / (
            (m.M[0][0] * m.minor(1, 2, 3, 1, 2, 3))
        - (m.M[0][1] * m.minor(1, 2, 3, 0, 2, 3))
        + (m.M[0][2] * m.minor(1, 2, 3, 0, 1, 3))
        - (m.M[0][3] * m.minor(1, 2, 3, 0, 1, 2)));
        var out: Matrix4f = undefined;
        out.M[0][0] =  m.minor(1, 2, 3, 1, 2, 3) * rcpDet;
        out.M[0][1] = -m.minor(0, 2, 3, 1, 2, 3) * rcpDet;
        out.M[0][2] =  m.minor(0, 1, 3, 1, 2, 3) * rcpDet;
        out.M[0][3] = -m.minor(0, 1, 2, 1, 2, 3) * rcpDet;
        out.M[1][0] = -m.minor(1, 2, 3, 0, 2, 3) * rcpDet;
        out.M[1][1] =  m.minor(0, 2, 3, 0, 2, 3) * rcpDet;
        out.M[1][2] = -m.minor(0, 1, 3, 0, 2, 3) * rcpDet;
        out.M[1][3] =  m.minor(0, 1, 2, 0, 2, 3) * rcpDet;
        out.M[2][0] =  m.minor(1, 2, 3, 0, 1, 3) * rcpDet;
        out.M[2][1] = -m.minor(0, 2, 3, 0, 1, 3) * rcpDet;
        out.M[2][2] =  m.minor(0, 1, 3, 0, 1, 3) * rcpDet;
        out.M[2][3] = -m.minor(0, 1, 2, 0, 1, 3) * rcpDet;
        out.M[3][0] = -m.minor(1, 2, 3, 0, 1, 2) * rcpDet;
        out.M[3][1] =  m.minor(0, 2, 3, 0, 1, 2) * rcpDet;
        out.M[3][2] = -m.minor(0, 1, 3, 0, 1, 2) * rcpDet;
        out.M[3][3] =  m.minor(0, 1, 2, 0, 1, 2) * rcpDet;
        return out;
    }
    pub fn createScale(x: f32, y: f32, z: f32) Matrix4f {
        return .{ .M = .{
            .{ x, 0, 0, 0 },
            .{ 0, y, 0, 0 },
            .{ 0, 0, z, 0 },
            .{ 0, 0, 0, 1 },
        } };
    }
    pub fn createTranslation(x: f32, y: f32, z: f32) Matrix4f {
        return .{ .M = .{
            .{ 1, 0, 0, x },
            .{ 0, 1, 0, y },
            .{ 0, 0, 1, z },
            .{ 0, 0, 0, 1 },
        } };
    }
    pub fn createRotation(radiansX: f32, radiansY: f32, radiansZ: f32) Matrix4f {
        const sinX: f32 = @sin(radiansX);
        const cosX: f32 = @cos(radiansX);
        const rotationX = Matrix4f{ .M = .{
            .{ 1, 0, 0, 0 },
            .{ 0, cosX, -sinX, 0 },
            .{ 0, sinX, cosX, 0 },
            .{ 0, 0, 0, 1 },
        } };
        const sinY: f32 = @sin(radiansY);
        const cosY: f32 = @cos(radiansY);
        const rotationY = Matrix4f{ .M = .{
            .{ cosY, 0, sinY, 0 },
            .{ 0, 1, 0, 0 },
            .{ -sinY, 0, cosY, 0 },
            .{ 0, 0, 0, 1 },
        } };
        const sinZ: f32 = @sin(radiansZ);
        const cosZ: f32 = @cos(radiansZ);
        const rotationZ = Matrix4f{ .M = .{
                .{ cosZ, -sinZ, 0, 0 },
                .{ sinZ, cosZ, 0, 0 },
                .{ 0, 0, 1, 0 },
                .{ 0, 0, 0, 1 },
        } };
        return rotationZ.multiply(rotationY).multiply(rotationX);
    }
    pub fn createProjection(minX: f32, maxX: f32, minY: f32, maxY: f32, nearZ: f32, farZ: f32) Matrix4f {
        const width: f32 = maxX - minX;
        const height: f32 = maxY - minY;
        const offsetZ: f32 = nearZ;
        var out: Matrix4f = undefined;
        if (farZ <= nearZ) {
            out.M[0][0] = (2.0 * nearZ) / width;
            out.M[0][1] = 0;
            out.M[0][2] = (maxX + minX) / width;
            out.M[0][3] = 0;
            out.M[1][0] = 0;
            out.M[1][1] = (2.0 * nearZ) / height;
            out.M[1][2] = (maxY + minY) / height;
            out.M[1][3] = 0;
            out.M[2][0] = 0;
            out.M[2][1] = 0;
            out.M[2][2] = -1.0;
            out.M[2][3] = -(nearZ + offsetZ);
            out.M[3][0] = 0;
            out.M[3][1] = 0;
            out.M[3][2] = -1.0;
            out.M[3][3] = 0;
        } else {
            out.M[0][0] = (2.0 * nearZ) / width;
            out.M[0][1] = 0;
            out.M[0][2] = (maxX + minX) / width;
            out.M[0][3] = 0;
            out.M[1][0] = 0;
            out.M[1][1] = (2.0 * nearZ) / height;
            out.M[1][2] = (maxY + minY) / height;
            out.M[1][3] = 0;
            out.M[2][0] = 0;
            out.M[2][1] = 0;
            out.M[2][2] = -(farZ + offsetZ) / (farZ - nearZ);
            out.M[2][3] = -(farZ * (nearZ + offsetZ)) / (farZ - nearZ);
            out.M[3][0] = 0;
            out.M[3][1] = 0;
            out.M[3][2] = -1.0;
            out.M[3][3] = 0;
        }
        return out;
    }
    pub fn createProjectionFov(fovDegreesX: f32, fovDegreesY: f32, offsetX: f32, offsetY: f32, nearZ: f32, farZ: f32) Matrix4f {
        const halfWidth: f32 = nearZ * std.math.tan(fovDegreesX * ((3.1415927410125732 / 180.0) * 0.5));
        const halfHeight: f32 = nearZ * std.math.tan(fovDegreesY * ((3.1415927410125732 / 180.0) * 0.5));
        const minX: f32 = offsetX - halfWidth;
        const maxX: f32 = offsetX + halfWidth;
        const minY: f32 = offsetY - halfHeight;
        const maxY: f32 = offsetY + halfHeight;
        return createProjection(minX, maxX, minY, maxY, nearZ, farZ);
    }
    pub fn createProjectionAsymmetricFov(leftDegrees: f32, rightDegrees: f32, upDegrees: f32, downDegrees: f32, nearZ: f32, farZ: f32) Matrix4f {
        const minX: f32 = -nearZ * std.math.tan(leftDegrees * (3.1415927410125732 / 180.0));
        const maxX: f32 = nearZ * std.math.tan(rightDegrees * (3.1415927410125732 / 180.0));
        const minY: f32 = -nearZ * std.math.tan(downDegrees * (3.1415927410125732 / 180.0));
        const maxY: f32 = nearZ * std.math.tan(upDegrees * (3.1415927410125732 / 180.0));
        return createProjection(minX, maxX, minY, maxY, nearZ, farZ);
    }
    pub fn transform(a: Matrix4f, v: Vector4f) Vector4f {
        var out: Vector4f = undefined;
        out.x = (((a.M[0][0] * v.x) + (a.M[0][1] * v.y)) + (a.M[0][2] * v.z)) + (a.M[0][3] * v.w);
        out.y = (((a.M[1][0] * v.x) + (a.M[1][1] * v.y)) + (a.M[1][2] * v.z)) + (a.M[1][3] * v.w);
        out.z = (((a.M[2][0] * v.x) + (a.M[2][1] * v.y)) + (a.M[2][2] * v.z)) + (a.M[2][3] * v.w);
        out.w = (((a.M[3][0] * v.x) + (a.M[3][1] * v.y)) + (a.M[3][2] * v.z)) + (a.M[3][3] * v.w);
        return out;
    }
    pub inline fn extractFov(m: Matrix4f) struct {
        leftDegrees: f32,
        rightDegrees: f32,
        upDegrees: f32,
        downDegrees: f32,
    } {
        const mt: Matrix4f = m.transpose();
        const leftEye = mt.transform(Vector4f.init(1, 0, 0, 1));
        const leftDegrees = -degreesFromRadians(std.math.atan(leftEye.z / leftEye.x));
        const rightEye = mt.transform(Vector4f.init(-1, 0, 0, 1));
        const rightDegrees = degreesFromRadians(std.math.atan(rightEye.z / rightEye.x));
        const downEye = mt.transform(Vector4f.init(0, 1, 0, 1));
        const downDegrees = -degreesFromRadians(std.math.atan(downEye.z / downEye.y));
        const upEye = mt.transform(Vector4f.init(0, -1, 0, 1));
        const upDegrees = degreesFromRadians(std.math.atan(upEye.z / upEye.y));
        return .{
            .leftDegrees = leftDegrees,
            .rightDegrees = rightDegrees,
            .upDegrees = upDegrees,
            .downDegrees = downDegrees,
        };
    }
    pub fn createFromQuaternion(q: Quatf) Matrix4f {
        const ww: f32 = q.w * q.w;
        const xx: f32 = q.x * q.x;
        const yy: f32 = q.y * q.y;
        const zz: f32 = q.z * q.z;
        var out: Matrix4f = undefined;
        out.M[0][0] = ((ww + xx) - yy) - zz;
        out.M[0][1] = 2.0 * ((q.x * q.y) - (q.w * q.z));
        out.M[0][2] = 2.0 * ((q.x * q.z) + (q.w * q.y));
        out.M[0][3] = 0;
        out.M[1][0] = 2.0 * ((q.x * q.y) + (q.w * q.z));
        out.M[1][1] = ((ww - xx) + yy) - zz;
        out.M[1][2] = 2.0 * ((q.y * q.z) - (q.w * q.x));
        out.M[1][3] = 0;
        out.M[2][0] = 2.0 * ((q.x * q.z) - (q.w * q.y));
        out.M[2][1] = 2.0 * ((q.y * q.z) + (q.w * q.x));
        out.M[2][2] = ((ww - xx) - yy) + zz;
        out.M[2][3] = 0;
        out.M[3][0] = 0;
        out.M[3][1] = 0;
        out.M[3][2] = 0;
        out.M[3][3] = 1;
        return out;
    }
    pub fn tanAngleMatrixFromProjection(projection: Matrix4f) Matrix4f {
        const tanAngleMatrix = Matrix4f{ .M = .{ .{
            0.5 * projection.M[0][0],
            0.0,
            (0.5 * projection.M[0][2]) - 0.5,
            0.0,
        }, .{
            0.0,
            0.5 * projection.M[1][1],
            (0.5 * projection.M[1][2]) - 0.5,
            0.0,
        }, .{
            0.0,
            0.0,
            -1.0,
            0.0,
        }, .{
            projection.M[2][2],
            projection.M[2][3],
            projection.M[3][2],
            1.0,
        } } };
        return tanAngleMatrix;
    }
    pub fn tanAngleMatrixFromUnitSquare(modelView: Matrix4f) Matrix4f {
        const inv: Matrix4f = modelView.inverse();
        const coef: f32 = if (inv.M[2][3] > 0.0) 1.0 else -1.0;
        var m: Matrix4f = undefined;
        m.M[0][0] = ((0.5 * ((inv.M[0][0] * inv.M[2][3]) - (inv.M[0][3] * inv.M[2][0]))) - (0.5 * inv.M[2][0])) * coef;
        m.M[0][1] = ((0.5 * ((inv.M[0][1] * inv.M[2][3]) - (inv.M[0][3] * inv.M[2][1]))) - (0.5 * inv.M[2][1])) * coef;
        m.M[0][2] = ((0.5 * ((inv.M[0][2] * inv.M[2][3]) - (inv.M[0][3] * inv.M[2][2]))) - (0.5 * inv.M[2][2])) * coef;
        m.M[0][3] = 0.0;
        m.M[1][0] = ((-0.5 * ((inv.M[1][0] * inv.M[2][3]) - (inv.M[1][3] * inv.M[2][0]))) - (0.5 * inv.M[2][0])) * coef;
        m.M[1][1] = ((-0.5 * ((inv.M[1][1] * inv.M[2][3]) - (inv.M[1][3] * inv.M[2][1]))) - (0.5 * inv.M[2][1])) * coef;
        m.M[1][2] = ((-0.5 * ((inv.M[1][2] * inv.M[2][3]) - (inv.M[1][3] * inv.M[2][2]))) - (0.5 * inv.M[2][2])) * coef;
        m.M[1][3] = 0.0;
        m.M[2][0] = -inv.M[2][0] * coef;
        m.M[2][1] = -inv.M[2][1] * coef;
        m.M[2][2] = -inv.M[2][2] * coef;
        m.M[2][3] = 0.0;
        m.M[3][0] = 0.0;
        m.M[3][1] = 0.0;
        m.M[3][2] = 0.0;
        m.M[3][3] = 1.0;
        return m;
    }
    pub fn tanAngleMatrixForCubeMap(viewMatrix: Matrix4f) Matrix4f {
        var m: Matrix4f = viewMatrix;
        {
            var i: usize = 0;
            while (i < 3) : (i += 1) {
                m.M[i][3] = 0.0;
            }
        }
        return m.inverse();
    }

};
pub const Posef = extern struct {
    Orientation: Quatf = Quatf.identity,
    Translation: Vector3f = Vector3f.zero,

    pub fn toMatrix(self: Posef) Matrix4f {
        var transform = Matrix4f.createFromQuaternion(self.Orientation);
        transform.M[0][3] = self.Translation.x;
        transform.M[1][3] = self.Translation.y;
        transform.M[2][3] = self.Translation.z;
        return transform;
    }
};
pub const Rectf = extern struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    pub const zero = Rectf{ .x = 0, .y = 0, .width = 0, .height = 0 };
    pub const unit = Rectf{ .x = 0, .y = 0, .width = 1, .height = 1 };
    pub const clip = Rectf{ .x = -1, .y = -1, .width = 2, .height = 2 };
};

pub const Eye = struct {
    pub const left = 0;
    pub const right = 1;
    pub const count = 2;
};

pub const StructureType = enum (u32) {
    init_parms = 1,
    mode_parms = 2,
    frame_parms = 3,
    mode_parms_vulkan = 5,
    _,
};

pub const DEVICE_TYPE_OCULUSQUEST_START: DeviceType = 256;
pub const DEVICE_TYPE_OCULUSQUEST: DeviceType = 259;
pub const DEVICE_TYPE_OCULUSQUEST_END: DeviceType = 319;
pub const DEVICE_TYPE_OCULUSQUEST2_START: DeviceType = 320;
pub const DEVICE_TYPE_OCULUSQUEST2: DeviceType = 320;
pub const DEVICE_TYPE_OCULUSQUEST2_END: DeviceType = 383;
pub const DEVICE_TYPE_UNKNOWN: DeviceType = -1;
pub const DeviceType = c_int;

pub const DeviceRegion = enum (u32) {
    unspecified = 0,
    japan = 1,
    china = 2,
    _,
};

pub const DeviceEmulationMode = enum (u32) {
    none = 0,
    go_on_quest = 1,
    _,
};

pub const InitializeStatus = enum (i32) {
    success = 0,
    unknown_error = -1,
    permissions_error = -2,
    already_initialized = -3,
    service_connection_failed = -4,
    device_not_supported = -5,
    _,
};

pub const GraphicsAPI = enum (u32) {
    opengl_es_2 = type_opengl_es | 0x0200,
    opengl_es_3 = type_opengl_es | 0x0300,

    opengl_compat = type_opengl | 0x0100,
    opengl_core_3 = type_opengl | 0x0300,
    opengl_core_4 = type_opengl | 0x0400,

    vulkan_1 = type_vulkan | 0x0100,

    _,

    pub const type_opengl_es: u32 = 0x10000;
    pub const type_opengl: u32 = 0x20000;
    pub const type_vulkan: u32 = 0x40000;
};

pub const InitParms = extern struct {
    Type: StructureType = .init_parms,
    ProductVersion: c_int = PRODUCT_VERSION,
    MajorVersion: c_int = MAJOR_VERSION,
    MinorVersion: c_int = MINOR_VERSION,
    PatchVersion: c_int = PATCH_VERSION,
    GraphicsAPI: GraphicsAPI = .opengl_es_2,
    Java: Java,
};

pub const MODE_FLAG_RESET_WINDOW_FULLSCREEN: c_int = 65280;
pub const MODE_FLAG_NATIVE_WINDOW: c_int = 65536;
pub const MODE_FLAG_FRONT_BUFFER_SRGB: c_int = 524288;
pub const MODE_FLAG_PHASE_SYNC: c_int = 4194304;
pub const ModeFlags = c_uint;

pub const ModeParms = extern struct {
    Type: StructureType = .mode_parms,
    Flags: ModeFlags = MODE_FLAG_RESET_WINDOW_FULLSCREEN,
    Java: Java,
    Display: c_ulonglong = 0,
    WindowSurface: c_ulonglong = 0,
    ShareContext: c_ulonglong = 0,
};

pub const ModeParmsVulkan = extern struct {
    Type: StructureType = .mode_parms_vulkan,
    Flags: ModeFlags = MODE_FLAG_RESET_WINDOW_FULLSCREEN,
    Java: Java,
    Display: c_ulonglong = 0,
    WindowSurface: c_ulonglong = 0,
    ShareContext: c_ulonglong = 0,
    SynchronizationQueue: c_ulonglong,
};

pub const Mobile = opaque {
    pub inline fn enterVrMode(parms: ModeParms) !*Mobile {
        const handle = vrapi_EnterVrMode(&parms);
        if (handle) |h| return h;
        return error.OVR_EnterVrMode_Failed;
    }
    extern fn vrapi_EnterVrMode(parms: *const ModeParms) ?*Mobile;

    pub const leaveVrMode = vrapi_LeaveVrMode;
    extern fn vrapi_LeaveVrMode(ovr: *Mobile) void;

    pub const getPredictedDisplayTime = vrapi_GetPredictedDisplayTime;
    pub const getPredictedTracking2 = vrapi_GetPredictedTracking2;
    pub const getPredictedTracking = vrapi_GetPredictedTracking;
    pub const getTrackingSpace = vrapi_GetTrackingSpace;
    pub const setTrackingSpace = vrapi_SetTrackingSpace;
    pub const locateTrackingSpace = vrapi_LocateTrackingSpace;

    pub inline fn getBoundaryGeometrySize(ovr: *Mobile) struct { point_count: u32, result: Result } {
        var count: u32 = 0;
        const result = vrapi_GetBoundaryGeometry(ovr, 0, &count, null);
        return .{ .point_count = count, .result = result };
    }
    pub inline fn getBoundaryGeometry(ovr: *Mobile, buffer: []Vector3f) struct {
        valid_geo: []Vector3f,
        full_count: u32,
        result: Result,
    } {
        var count: u32 = 0;
        const result = vrapi_GetBoundaryGeometry(ovr, @intCast(u32, buffer.len), &count, buffer.ptr);
        return .{
            .valid_geo = buffer[0..std.math.min(count, buffer.len)],
            .full_count = count,
            .result = result,
        };
    }

    pub const getBoundaryOrientedBoundingBox = vrapi_GetBoundaryOrientedBoundingBox;
    pub const testPointIsInBoundary = vrapi_TestPointIsInBoundary;
    pub const getBoundaryTriggerState = vrapi_GetBoundaryTriggerState;
    pub const requestBoundaryVisible = vrapi_RequestBoundaryVisible;
    pub const getBoundaryVisible = vrapi_GetBoundaryVisible;
    pub const waitFrame = vrapi_WaitFrame;
    pub const beginFrame = vrapi_BeginFrame;
    pub inline fn submitFrame2(self: *@This(), frameDescription: SubmitFrameDescription2) Result {
        return vrapi_SubmitFrame2(self, &frameDescription);
    }
    pub const setClockLevels = vrapi_SetClockLevels;
    pub const setPerfThread = vrapi_SetPerfThread;
    pub const setExtraLatencyMode = vrapi_SetExtraLatencyMode;
    pub const getHmdColorDesc = vrapi_GetHmdColorDesc;
    pub fn setClientColorDesc(self: *@This(), colorDesc: HmdColorDesc) Result {
        return vrapi_SetClientColorDesc(self, &colorDesc);
    }
    pub const setDisplayRefreshRate = vrapi_SetDisplayRefreshRate;

    pub const getHandPose = vrapi_GetHandPose;
    pub const getHandSkeleton = vrapi_GetHandSkeleton;
    pub const getHandMesh = vrapi_GetHandMesh;

    pub const enumerateInputDevices = vrapi_EnumerateInputDevices;
    pub const getInputDeviceCapabilities = vrapi_GetInputDeviceCapabilities;

    pub const setHapticVibrationSimple = vrapi_SetHapticVibrationSimple;
    pub const setHapticVibrationBuffer = vrapi_SetHapticVibrationBuffer;

    pub const getCurrentInputState = vrapi_GetCurrentInputState;
    pub const getInputTrackingState = vrapi_GetInputTrackingState;

    extern fn vrapi_GetPredictedDisplayTime(ovr: *Mobile, frameIndex: u64) f64;
    extern fn vrapi_GetPredictedTracking2(ovr: *Mobile, absTimeInSeconds: f64) Tracking2;
    extern fn vrapi_GetPredictedTracking(ovr: *Mobile, absTimeInSeconds: f64) Tracking;
    extern fn vrapi_GetTrackingSpace(ovr: *Mobile) TrackingSpace;
    extern fn vrapi_SetTrackingSpace(ovr: *Mobile, whichSpace: TrackingSpace) Result;
    extern fn vrapi_LocateTrackingSpace(ovr: *Mobile, target: TrackingSpace) Posef;
    extern fn vrapi_GetBoundaryGeometry(ovr: *Mobile, pointsCountInput: u32, pointsCountOutput: *u32, points: ?[*]Vector3f) Result;
    extern fn vrapi_GetBoundaryOrientedBoundingBox(ovr: *Mobile, pose: *Posef, scale: *Vector3f) Result;
    extern fn vrapi_TestPointIsInBoundary(ovr: *Mobile, point: Vector3f, pointInsideBoundary: *bool, result: ?*BoundaryTriggerResult) Result;
    extern fn vrapi_GetBoundaryTriggerState(ovr: *Mobile, deviceId: TrackedDeviceTypeId, result: *BoundaryTriggerResult) Result;
    extern fn vrapi_RequestBoundaryVisible(ovr: *Mobile, visible: bool) Result;
    extern fn vrapi_GetBoundaryVisible(ovr: *Mobile, visible: *bool) Result;

    extern fn vrapi_WaitFrame(ovr: *Mobile, frameIndex: u64) Result;
    extern fn vrapi_BeginFrame(ovr: *Mobile, frameIndex: u64) Result;
    extern fn vrapi_SubmitFrame2(ovr: *Mobile, frameDescription: *const SubmitFrameDescription2) Result;
    extern fn vrapi_SetClockLevels(ovr: *Mobile, cpuLevel: i32, gpuLevel: i32) Result;
    extern fn vrapi_SetPerfThread(ovr: *Mobile, @"type": PerfThreadType, threadId: u32) Result;
    extern fn vrapi_SetExtraLatencyMode(ovr: *Mobile, mode: ExtraLatencyMode) Result;
    extern fn vrapi_GetHmdColorDesc(ovr: *Mobile) HmdColorDesc;
    extern fn vrapi_SetClientColorDesc(ovr: *Mobile, colorDesc: *const HmdColorDesc) Result;
    extern fn vrapi_SetDisplayRefreshRate(ovr: *Mobile, refreshRate: f32) Result;

    extern fn vrapi_GetHandPose(ovr: *Mobile, deviceID: DeviceID, absTimeInSeconds: f64, header: *HandPoseHeader) Result;
    extern fn vrapi_GetHandSkeleton(ovr: *Mobile, handedness: Handedness, header: *HandSkeletonHeader) Result;
    extern fn vrapi_GetHandMesh(ovr: *Mobile, handedness: Handedness, header: *HandMeshHeader) Result;
    extern fn vrapi_EnumerateInputDevices(ovr: *Mobile, index: u32, capsHeader: *InputCapabilityHeader) Result;
    extern fn vrapi_GetInputDeviceCapabilities(ovr: *Mobile, capsHeader: *InputCapabilityHeader) Result;
    extern fn vrapi_SetHapticVibrationSimple(ovr: *Mobile, deviceID: DeviceID, intensity: f32) Result;
    extern fn vrapi_SetHapticVibrationBuffer(ovr: *Mobile, deviceID: DeviceID, hapticBuffer: *const HapticBuffer) Result;
    extern fn vrapi_GetCurrentInputState(ovr: *Mobile, deviceID: DeviceID, inputState: *InputStateHeader) Result;
    extern fn vrapi_GetInputTrackingState(ovr: *Mobile, deviceID: DeviceID, absTimeInSeconds: f64, tracking: *Tracking) Result;
};

pub const RigidBodyPosef = extern struct {
    Pose: Posef = .{},
    AngularVelocity: Vector3f = Vector3f.zero,
    LinearVelocity: Vector3f = Vector3f.zero,
    AngularAcceleration: Vector3f = Vector3f.zero,
    LinearAcceleration: Vector3f = Vector3f.zero,
    dead16: [4]u8 = undefined,
    TimeInSeconds: f64 = 0,
    PredictionInSeconds: f64 = 0,
};

pub const TrackingStatus = packed struct {
    orientation_tracked: bool align(4) = false,
    position_tracked: bool = false,
    orientation_valid: bool = false,
    position_valid: bool = false,
    __pad0: u3 = 0,
    hmd_connected: bool = false,
    __pad1: u8 = 0,
    __pad2: u16 = 0,
};

pub const Tracking2 = extern struct {
    Status: TrackingStatus,
    dead18: [4]u8 = undefined,
    HeadPose: RigidBodyPosef,
    Eye: [Eye.count]extern struct {
        ProjectionMatrix: Matrix4f,
        ViewMatrix: Matrix4f,
    },
};

pub const Tracking = extern struct {
    Status: TrackingStatus,
    dead20: [4]u8 = undefined,
    HeadPose: RigidBodyPosef,
};

pub const TrackingTransform = enum (u32) {
    identity = 0,
    current = 1,
    system_center_eye_level = 2,
    system_center_floor_level = 3,
    _,
};

pub const TrackingSpace = enum (u32) {
    local = 0,
    local_floor = 1,
    local_tilted = 2,
    stage = 3,
    local_fixed_yaw = 7,
    _,
};

pub const TrackedDeviceTypeId = enum (i32) {
    none = -1,
    hmd = 0,
    hand_left = 1,
    hand_right = 2,
    _,

    pub const num = 3;
};

pub const BoundaryTriggerResult = extern struct {
    ClosestPoint: Vector3f,
    ClosestPointNormal: Vector3f,
    ClosestDistance: f32,
    IsTriggering: bool,
};

pub const TextureType = enum (u32) {
    @"2d" = 0,
    @"2d_array" = 2,
    cube = 3,
    _,

    pub const max = 4;
};

pub const TextureFormat = enum (u32) {
    nne = 0,
    @"565" = 1,
    @"5551" = 2,
    @"4444" = 3,
    @"8888" = 4,
    @"8888_srgb" = 5,
    rgba16f = 6,
    depth_16 = 7,
    depth_24 = 8,
    depth_24_stencil_8 = 9,
    rg16 = 10,
    _,
};

pub const TextureFilter = enum (u32) {
    nearest = 0,
    linear = 1,
    nearest_mipmap_linear = 2,
    linear_mipmap_nearest = 3,
    linear_mipmap_linear = 4,
    cubic = 5,
    cubic_mipmap_nearest = 6,
    cubic_mipmap_linear = 7,
    _,
};

pub const TextureWrapMode = enum (u32) {
    repeat = 0,
    clamp_to_edge = 1,
    clamp_to_border = 2,
    _,
};

pub const TextureSamplerState = extern struct {
    MinFilter: TextureFilter,
    MagFilter: TextureFilter,
    WrapModeS: TextureWrapMode,
    WrapModeT: TextureWrapMode,
    BorderColor: [4]f32,
    MaxAnisotropy: f32,

    pub fn default(texType: TextureType, mipCount: c_int) TextureSamplerState {
        return .{
            .MinFilter = if (mipCount > 1) .linear_mipmap_linear else .linear,
            .MagFilter = .linear,
            .WrapModeS = if (texType != .cube) .clamp_to_edge else .repeat,
            .WrapModeT = if (texType != .cube) .clamp_to_edge else .repeat,
            .BorderColor = .{ 0, 0, 0, 0 },
            .MaxAnisotropy = 1.0,
        };
    }
};

pub const AndroidSurfaceSwapChainFlags = packed struct {
    protected: bool align(8) = false,
    synchronous: bool = false,
    use_timestamps: bool = false,
    __pad: u61 = 0,
};

pub const TextureSwapChain = opaque {
    pub const default = @intToPtr(*TextureSwapChain, 1);
    pub const default_loading_icon = @intToPtr(*TextureSwapChain, 2);

    pub fn create4(createInfo: SwapChainCreateInfo) ?*TextureSwapChain {
        return vrapi_CreateTextureSwapChain4(&createInfo);
    }
    pub const create3 = vrapi_CreateTextureSwapChain3;
    pub const create2 = vrapi_CreateTextureSwapChain2;
    pub const create = vrapi_CreateTextureSwapChain;

    pub const createAndroidSurfaceSwapChain = vrapi_CreateAndroidSurfaceSwapChain;
    pub const createAndroidSurfaceSwapChain2 = vrapi_CreateAndroidSurfaceSwapChain2;
    pub fn createAndroidSurfaceSwapChain3(width: c_int, height: c_int, flags: AndroidSurfaceSwapChainFlags) ?*TextureSwapChain {
        return vrapi_CreateAndroidSurfaceSwapChain3(width, height, @bitCast(u64, flags));
    }

    pub const destroy = vrapi_DestroyTextureSwapChain;

    pub const getLength = vrapi_GetTextureSwapChainLength;
    pub const getHandle = vrapi_GetTextureSwapChainHandle;
    pub const getAndroidSurface = vrapi_GetTextureSwapChainAndroidSurface;
    pub fn setSamplerState(self: *@This(), samplerState: TextureSamplerState) Result {
        return vrapi_SetTextureSwapChainSamplerState(self, &samplerState);
    }
    pub fn getSamplerState(self: *@This(), samplerState: *TextureSamplerState) Result {
        return vrapi_GetTextureSwapChainSamplerState(self, samplerState);
    }

    extern fn vrapi_CreateTextureSwapChain4(createInfo: *const SwapChainCreateInfo) ?*TextureSwapChain;
    extern fn vrapi_CreateTextureSwapChain3(@"type": TextureType, format: i64, width: c_int, height: c_int, levels: c_int, bufferCount: c_int) ?*TextureSwapChain;
    extern fn vrapi_CreateTextureSwapChain2(@"type": TextureType, format: TextureFormat, width: c_int, height: c_int, levels: c_int, bufferCount: c_int) ?*TextureSwapChain;
    extern fn vrapi_CreateTextureSwapChain(@"type": TextureType, format: TextureFormat, width: c_int, height: c_int, levels: c_int, buffered: bool) ?*TextureSwapChain;
    extern fn vrapi_CreateAndroidSurfaceSwapChain(width: c_int, height: c_int) ?*TextureSwapChain;
    extern fn vrapi_CreateAndroidSurfaceSwapChain2(width: c_int, height: c_int, isProtected: bool) ?*TextureSwapChain;
    extern fn vrapi_CreateAndroidSurfaceSwapChain3(width: c_int, height: c_int, flags: u64) ?*TextureSwapChain;
    extern fn vrapi_DestroyTextureSwapChain(chain: *TextureSwapChain) void;
    extern fn vrapi_GetTextureSwapChainLength(chain: *TextureSwapChain) c_int;
    extern fn vrapi_GetTextureSwapChainHandle(chain: *TextureSwapChain, index: c_int) c_uint;
    extern fn vrapi_GetTextureSwapChainAndroidSurface(chain: *TextureSwapChain) android.jobject;
    extern fn vrapi_SetTextureSwapChainSamplerState(chain: *TextureSwapChain, samplerState: *const TextureSamplerState) Result;
    extern fn vrapi_GetTextureSwapChainSamplerState(chain: *TextureSwapChain, samplerState: *TextureSamplerState) Result;
};

pub const SwapChainCreateFlags = packed struct {
    subsampled: bool align(8) = false,
    __pad: u63 = 0,
};

pub const SwapChainUsageFlags = packed struct {
    color_attachment: bool align(8) = false,
    depth_stencil_attachment: bool = false,
    __pad: u62 = 0,
};

pub const SwapChainCreateInfo = extern struct {
    Format: i64,
    Width: c_int,
    Height: c_int,
    Levels: c_int,
    FaceCount: c_int,
    ArraySize: c_int,
    BufferCount: c_int,
    CreateFlags: SwapChainCreateFlags,
    UsageFlags: SwapChainUsageFlags,
};

pub const FrameFlags = packed struct {
    __pad0: u1 align(4) = 0,
    flush: bool = false,
    final: bool = false,
    __pad1: u3 = 0,
    inhibit_volume_layer: bool = false,
    __pad2: u25 = 0,
};

pub const FrameLayerFlags = packed struct {
    __pad0: u1 align(4) = 0,
    chromatic_aberration_correction: bool = false,
    fixed_to_view: bool = false,
    spin: bool = false,
    clip_to_texture_rect: bool = false,
    __pad1: u3 = 0,

    inhibit_srgb_framebuffer: bool = false,
    __pad2: u7 = 0,

    __pad3: u3 = 0,
    filter_expensive: bool = false,
    __pad4: u12 = 0,
};

pub const FrameLayerEye = struct {
    pub const left = 0;
    pub const right = 1;
    pub const max = 2;
};

pub const FrameLayerBlend = enum (u32) {
    zero = 0,
    one = 1,
    src_alpha = 2,
    one_minus_src_alpha = 5,
    _,
};

pub const ExtraLatencyMode = enum (u32) {
    off = 0,
    on = 1,
    dynamic = 2,
    _,
};

pub const LayerType2 = enum (u32) {
    projection2 = 1,
    cylinder2 = 3,
    cube2 = 4,
    equirect2 = 5,
    loading_icon2 = 6,
    fisheye2 = 7,
    equirect3 = 10,
    _,
};

const default_projection = Matrix4f.createProjectionFov(90.0, 90.0, 0.0, 0.0, 0.10000000149011612, 0.0);
const default_tan_angles = default_projection.tanAngleMatrixFromProjection();

pub const LayerHeader2 = extern struct {
    Type: LayerType2,
    Flags: FrameLayerFlags = .{},
    ColorScale: Vector4f = .{ .x = 1, .y = 1, .z = 1, .w = 1 },
    SrcBlend: FrameLayerBlend = .one,
    DstBlend: FrameLayerBlend = .zero,
    Reserved: ?*c_void = null,
};
pub const LayerProjection2 = extern struct {
    Header: LayerHeader2 = .{ .Type = .projection2 },
    HeadPose: RigidBodyPosef = .{},
    Textures: [FrameLayerEye.max]EyeData = [_]EyeData{ .{} } ** FrameLayerEye.max,
    
    pub const EyeData = extern struct {
        ColorSwapChain: ?*TextureSwapChain = null,
        SwapChainIndex: c_int = 0,
        TexCoordsFromTanAngles: Matrix4f = Matrix4f.identity,
        TextureRect: Rectf = Rectf.unit,
    };

    pub const default = LayerProjection2{
        .Textures = [_]EyeData{ .{
            .TexCoordsFromTanAngles = default_tan_angles,
        } } ** FrameLayerEye.max,
    };
    pub const default_black = defaultSolidColor(Vector4f.zero);

    pub fn defaultSolidColor(color: Vector4f) LayerProjection2 {
        return .{
            .Header = .{
                .Type = .projection2,
                .ColorScale = color,
            },
            .Textures = [_]EyeData{ .{
                .ColorSwapChain = TextureSwapChain.default,
            } } ** FrameLayerEye.max,
        };
    }
};

pub const LayerCylinder2 = extern struct {
    Header: LayerHeader2 = .{ .Type = .cylinder2 },
    HeadPose: RigidBodyPosef = .{},
    Textures: [FrameLayerEye.max]EyeData = [_]EyeData{ .{} } ** FrameLayerEye.max,

    pub const EyeData = extern struct {
        ColorSwapChain: ?*TextureSwapChain = null,
        SwapChainIndex: c_int = 0,
        TexCoordsFromTanAngles: Matrix4f = Matrix4f.identity,
        TextureRect: Rectf = Rectf.unit,
        TextureMatrix: Matrix4f = Matrix4f.identity,
    };

    pub const default = LayerCylinder2{
        .Textures = [_]EyeData{ .{
            .TexCoordsFromTanAngles = default_tan_angles,
        } } ** FrameLayerEye.max,
    };
};
pub const LayerCube2 = extern struct {
    Header: LayerHeader2 = .{ .Type = .cube2 },
    HeadPose: RigidBodyPosef = .{},
    TexCoordsFromTanAngles: Matrix4f = Matrix4f.identity,
    Offset: Vector3f = Vector3f.zero,
    Textures: [FrameLayerEye.max]EyeData = [_]EyeData{ .{} } ** FrameLayerEye.max,
    
    pub const EyeData = extern struct {
        ColorSwapChain: ?*TextureSwapChain = null,
        SwapChainIndex: c_int = 0,
    };

    pub const default = LayerCube2{};
};
pub const LayerEquirect2 = extern struct {
    Header: LayerHeader2 = .{ .Type = .equirect2 },
    HeadPose: RigidBodyPosef = .{},
    TexCoordsFromTanAngles: Matrix4f = Matrix4f.identity,
    Textures: [FrameLayerEye.max]EyeData = [_]EyeData{ .{} } ** FrameLayerEye.max,

    pub const EyeData = extern struct {
        ColorSwapChain: ?*TextureSwapChain = null,
        SwapChainIndex: c_int = 0,
        TextureRect: Rectf = Rectf.unit,
        TextureMatrix: Matrix4f = Matrix4f.identity,
    };

    pub const default = LayerEquirect2{};
};
pub const LayerEquirect3 = extern struct {
    Header: LayerHeader2 = .{ .Type = .equirect3 },
    HeadPose: RigidBodyPosef = .{},
    Textures: [FrameLayerEye.max]EyeData = [_]EyeData{ .{} } ** FrameLayerEye.max,
    
    pub const EyeData = extern struct {
        ColorSwapChain: ?*TextureSwapChain = null,
        SwapChainIndex: c_int = 0,
        TexCoordsFromTanAngles: Matrix4f = Matrix4f.identity_3x3,
        TextureRect: Rectf = Rectf.unit,
        TextureMatrix: Matrix4f = Matrix4f.identity,
    };

    pub const default = LayerEquirect3{};
};
pub const LayerLoadingIcon2 = extern struct {
    Header: LayerHeader2 = .{
        .Type = .loading_icon2,
        .SrcBlend = .src_alpha,
        .DstBlend = .one_minus_src_alpha,
    },
    SpinSpeed: f32 = 1,
    SpinScale: f32 = 16,
    ColorSwapChain: ?*TextureSwapChain = TextureSwapChain.default_loading_icon,
    SwapChainIndex: c_int = 0,

    pub const default = LayerLoadingIcon2{};
};
pub const LayerFishEye2 = extern struct {
    Header: LayerHeader2 = .{ .Type = .fisheye2 },
    HeadPose: RigidBodyPosef = .{},
    Textures: [FrameLayerEye.max]EyeData = [_]EyeData{ .{} } ** FrameLayerEye.max,
    
    pub const EyeData = extern struct {
        ColorSwapChain: ?*TextureSwapChain = null,
        SwapChainIndex: c_int = 0,
        LensFromTanAngles: Matrix4f = Matrix4f.identity,
        TextureRect: Rectf = Rectf.unit,
        TextureMatrix: Matrix4f = Matrix4f.identity,
        Distortion: Vector4f = Vector4f.zero,
    };

    pub const default = LayerFishEye2{
        .Textures = [_]EyeData{ .{
            .TexCoordsFromTanAngles = default_tan_angles,
        } } ** FrameLayerEye.max,
    };
};
pub const Layer_Union2 = extern union {
    Header: LayerHeader2,
    Projection: LayerProjection2,
    Cylinder: LayerCylinder2,
    Cube: LayerCube2,
    Equirect: LayerEquirect2,
    Equirect3: LayerEquirect3,
    LoadingIcon: LayerLoadingIcon2,
    FishEye: LayerFishEye2,
};
pub const SubmitFrameDescription2 = extern struct {
    Flags: FrameFlags,
    SwapInterval: u32,
    FrameIndex: u64,
    DisplayTime: f64,
    Pad: [8]u8 = std.mem.zeroes([8]u8),
    LayerCount: u32,
    Layers: ?[*]const ?*const LayerHeader2,
};

pub const PerfThreadType = enum (u32) {
    main = 0,
    renderer = 1,
    _,
};

pub const ColorSpace = enum (u32) {
    unmanaged = 0,
    rec_2020 = 1,
    rec_709 = 2,
    rift_cv1 = 3,
    rift_s = 4,
    quest = 5,
    p3 = 6,
    adobe_rgb = 7,
    _,
};

pub const HmdColorDesc = extern struct {
    ColorSpace: ColorSpace,
    dead52: [4]u8,
};

pub const EventType = enum (u32) {
    none = 0,
    data_lost = 1,
    visibility_gained = 2,
    visibility_lost = 3,
    focus_gained = 4,
    focus_lost = 5,
    display_refresh_rate_change = 11,
    _,
};

pub const EventHeader = extern struct {
    EventType: EventType,

    pub fn cast(self: *@This(), comptime EventT: type) *EventT {
        std.debug.assert(self.EventType == EventT.tag);
        return @ptrCast(*EventT, self);
    }

    pub fn tryCast(self: *@This(), comptime EventT: type) ?*EventT {
        if (self.EventType != EventT.tag) return null;
        return @ptrCast(*EventT, self);
    }
};

pub const EventDataLost = extern struct {
    pub const tag: EventType = .data_lost;

    EventHeader: EventHeader,
};
pub const EventVisibilityGained = extern struct {
    pub const tag: EventType = .visibility_gained;

    EventHeader: EventHeader,
};
pub const EventVisibilityLost = extern struct {
    pub const tag: EventType = .visibility_lost;

    EventHeader: EventHeader,
};
pub const EventFocusGained = extern struct {
    pub const tag: EventType = .focus_gained;

    EventHeader: EventHeader,
};
pub const EventFocusLost = extern struct {
    pub const tag: EventType = .focus_lost;

    EventHeader: EventHeader,
};
pub const EventDisplayRefreshRateChange = extern struct {
    pub const tag: EventType = .display_refresh_rate_change;

    EventHeader: EventHeader,
    fromDisplayRefreshRate: f32,
    toDisplayRefreshRate: f32,
};

pub const EventDataBuffer = extern struct {
    pub const tag = @compileError("Cannot cast to EventDataBuffer, it is not a real event type.");

    EventHeader: EventHeader,
    EventData: [4000]u8,

    pub fn cast(self: *@This(), comptime EventT: type) *EventT {
        return self.EventHeader.cast(EventT);
    }

    pub fn tryCast(self: *@This(), comptime EventT: type) ?*EventT {
        return self.EventHeader.tryCast(EventT);
    }
};

pub const LARGEST_EVENT_TYPE = EventDataBuffer;
pub const MAX_EVENT_SIZE = @sizeOf(LARGEST_EVENT_TYPE);
pub const MAX_EVENT_ALIGN = @alignOf(LARGEST_EVENT_TYPE);

pub const Buttons = packed struct {
    a: bool align(4) = false,
    b: bool = false,
    r_thumb: bool = false,
    r_shoulder: bool = false,
    __pad0: u4 = 0,

    x: bool = false,
    y: bool = false,
    l_thumb: bool = false,
    l_shoulder: bool = false,
    __pad1: u4 = 0,

    up: bool = false,
    down: bool = false,
    left: bool = false,
    right: bool = false,
    enter: bool = false,
    back: bool = false,
    __pad2: u2 = 0,

    __pad3: u2 = 0,
    grip_trigger: bool = false,
    __pad4: u2 = 0,
    trigger: bool = false,
    __pad5: u1 = 0,
    joystick: bool = false,
};

pub const Touches = packed struct {
    a: bool align(4) = false,
    b: bool = false,
    x: bool = false,
    y: bool = false,
    track_pad: bool = false,
    joystick: bool = false,
    index_trigger: bool = false,
    __pad0: u1 = 0,

    pointers: enum (u2) {
        none = 0,
        thumb_up = 1,
        index_pointing = 2,
        base_state = 3,
    } = .none,
    l_thumb: bool = false,
    r_thumb: bool = false,
    thumb_rest: bool = false,
    l_thumb_rest: bool = false,
    r_thumb_rest: bool = false,
    __pad1: u1 = 0,

    __pad2: u16 = 0,
};

pub const ControllerType = enum (u32) {
    none = 0,
    reserved0 = 1 << 0,
    reserved1 = 1 << 1,
    tracked_remote = 1 << 2,
    hand = 1 << 5,
    standard_pointer = 1 << 7,
    _,
};

pub const ControllerTypes = packed struct {
    reserved0: bool align(4) = false,
    reserved1: bool = false,
    tracked_remote: bool = false,
    __pad0: u2 = 0,
    hand: bool = false,
    __pad1: u1 = 0,
    standard_pointer: bool = false,

    __pad2: u8 = 0,
    __pad3: u16 = 0,

    pub fn has(self: @This(), ct: ControllerType) bool {
        return @bitCast(u32, self) & @enumToInt(ct) != 0;
    }
};

pub const DeviceID = u32;

pub const DeviceIdType_Invalid: c_int = 2147483647;
pub const DeviceIdType = c_uint;

pub const InputCapabilityHeader = extern struct {
    Type: ControllerType,
    DeviceID: DeviceID,
};

pub const ControllerCapabilities = packed struct {
    has_orientation_tracking: bool align(4) = false,
    has_position_tracking: bool = false,
    left_hand: bool = false,
    right_hand: bool = false,
    model_oculus_go: bool = false,
    __pad0: u1 = 0,
    has_analog_index_trigger: bool = false,
    has_analog_grip_trigger: bool = false,

    __pad1: u1 = 0,
    has_simple_haptic_vibration: bool = false,
    has_buffered_haptic_vibration: bool = false,
    model_gear_vr: bool = false,
    has_trackpad: bool = false,
    has_joystick: bool = false,
    model_oculus_touch: bool = false,
    __pad2: u1 = 0,
    
    __pad3: u16 = 0,
};

pub const InputTrackedRemoteCapabilities = extern struct {
    pub const caps_tag: ControllerType = .tracked_remote;

    Header: InputCapabilityHeader,
    ControllerCapabilities: ControllerCapabilities,
    ButtonCapabilities: Buttons,
    TrackpadMaxX: u16,
    TrackpadMaxY: u16,
    TrackpadSizeX: f32,
    TrackpadSizeY: f32,
    HapticSamplesMax: u32,
    HapticSampleDurationMS: u32,
    TouchCapabilities: Touches,
    Reserved4: u32,
    Reserved5: u32,
};
pub const InputStandardPointerCapabilities = extern struct {
    pub const caps_tag: ControllerType = .standard_pointer;

    Header: InputCapabilityHeader,
    ControllerCapabilities: ControllerCapabilities,
    HapticSamplesMax: u32,
    HapticSampleDurationMS: u32,
    Reserved: [20]u64,
};
pub const HapticBuffer = extern struct {
    BufferTime: f64,
    NumSamples: u32,
    Terminated: bool,
    HapticBuffer: ?[*]u8,
};
pub const InputStateHeader = extern struct {
    ControllerType: ControllerType,
    TimeInSeconds: f64,
};
pub const InputStateTrackedRemote = extern struct {
    pub const state_tag: ControllerType = .tracked_remote;

    Header: InputStateHeader,
    Buttons: Buttons,
    TrackpadStatus: enum (u32) {
        off_trackpad = 0,
        on_trackpad = 1,
        _,
    },
    TrackpadPosition: Vector2f,
    BatteryPercentRemaining: u8,
    RecenterCount: u8,
    Reserved: u16,
    IndexTrigger: f32,
    GripTrigger: f32,
    Touches: Touches,
    Reserved5a: u32,
    Joystick: Vector2f,
    JoystickNoDeadZone: Vector2f,
};

pub const InputStateStandardPointerStatus = packed struct {
    __pad0: u1 align(4) = 0,
    pointer_valid: bool = false,
    menu_pressed: bool = false,
    __pad1: u29 = 0,
};
pub const InputStateStandardPointer = extern struct {
    pub const state_tag: ControllerType = .standard_pointer;

    Header: InputStateHeader,
    PointerPose: Posef,
    PointerStrength: f32,
    GripPose: Posef,
    InputStateStatus: InputStateStandardPointerStatus,
    Reserved: [20]u64,
};

pub const Handedness = enum (u32) {
    unknown = 0,
    left = 1,
    right = 2,
    _,
};

pub const HandCapabilities = packed struct {
    left_hand: bool align(4) = false,
    right_hand: bool = false,
    __pad0: u30 = 0,
};

pub const HandStateCapabilities = packed struct {
    pinch_index: bool align(4) = false,
    pinch_middle: bool = false,
    pinch_ring: bool = false,
    pinch_pinky: bool = false,
    __pad0: u28 = 0,
};
pub const InputHandCapabilities = extern struct {
    pub const caps_tag: ControllerType = .hand;

    Header: InputCapabilityHeader,
    HandCapabilities: HandCapabilities,
    StateCapabilities: HandStateCapabilities,
};

pub const HandTrackingStatus = enum (u32) {
    untracked = 0,
    tracked = 1,
    _,
};

pub const HandFingers = struct {
    pub const thumb = 0;
    pub const index = 1;
    pub const middle = 2;
    pub const ring = 3;
    pub const pinky = 4;

    pub const max = 5;
};

pub const HandPinchStrength = struct {
    pub const index = 0;
    pub const middle = 1;
    pub const ring = 2;
    pub const pinky = 3;

    pub const max = 4;
};

pub const VertexIndex = i16;

pub const HandBone = struct {
    pub const invalid: c_int = -1;
    pub const wrist_root: c_int = 0;
    pub const forearm_stub: c_int = 1;
    pub const thumb0: c_int = 2;
    pub const thumb1: c_int = 3;
    pub const thumb2: c_int = 4;
    pub const thumb3: c_int = 5;
    pub const index1: c_int = 6;
    pub const index2: c_int = 7;
    pub const index3: c_int = 8;
    pub const middle1: c_int = 9;
    pub const middle2: c_int = 10;
    pub const middle3: c_int = 11;
    pub const ring1: c_int = 12;
    pub const ring2: c_int = 13;
    pub const ring3: c_int = 14;
    pub const pinky0: c_int = 15;
    pub const pinky1: c_int = 16;
    pub const pinky2: c_int = 17;
    pub const pinky3: c_int = 18;
    pub const thumb_tip: c_int = 19;
    pub const index_tip: c_int = 20;
    pub const middle_tip: c_int = 21;
    pub const ring_tip: c_int = 22;
    pub const pinky_tip: c_int = 23;

    pub const max_skinnable: c_int = 19;
    pub const max: c_int = 24;
};
pub const HandBoneIndex = i16;

pub const Confidence_LOW: c_uint = 0;
pub const Confidence_HIGH: c_uint = 1065353216;
pub const Confidence = c_uint;

pub const HandVersion = enum (u32) {
    version_1 = 0xdf000001,
    _,
};

pub const BoneCapsule = extern struct {
    BoneIndex: HandBoneIndex,
    Points: [2]Vector3f,
    Radius: f32,
};

pub const HandConstants = struct {
    pub const max_vertices = 3000;
    pub const max_indices = 18000;
    pub const max_fingers = HandFingers.max;
    pub const max_pinch_strengths = HandPinchStrength.max;
    pub const max_skinnable_bones = HandBone.max_skinnable;
    pub const max_bones = HandBone.max;
    pub const max_capsules = HandBone.max_skinnable;
};

pub const InputStateHandStatus = packed struct {
    __pad0: u1 align(4) = 0,
    pointer_valid: bool = false,
    index_pinching: bool = false,
    middle_pinching: bool = false,
    ring_pinching: bool = false,
    pinky_pinching: bool = false,
    system_gesture_processing: bool = false,
    dominant_hand: bool = false,

    menu_pressed: bool = false,
    __pad1: u7 = 0,

    __pad2: u16 = 0,
};
pub const InputStateHand = extern struct {
    pub const state_tag: ControllerType = .hand;

    Header: InputStateHeader,
    PinchStrength: [HandPinchStrength.max]f32,
    PointerPose: Posef,
    InputStateStatus: InputStateHandStatus,
};
pub const HandPoseHeader = extern struct {
    Version: HandVersion,
    Reserved: f64 = undefined,
};
pub const HandPose = extern struct {
    Header: HandPoseHeader = .{ .Version = .version_1 },
    Status: HandTrackingStatus = .untracked,
    RootPose: Posef = undefined,
    BoneRotations: [HandBone.max]Quatf = undefined,
    RequestedTimeStamp: f64 = undefined,
    SampleTimeStamp: f64 = undefined,
    HandConfidence: Confidence = undefined,
    HandScale: f32 = undefined,
    FingerConfidences: [HandFingers.max]Confidence = undefined,
};
pub const HandSkeletonHeader = extern struct {
    Version: HandVersion,
};
pub const HandSkeleton_V1 = extern struct {
    Header: HandSkeletonHeader = .{ .Version = .version_1 },
    NumBones: u32 = 0,
    NumCapsules: u32 = 0,
    Reserved: [5]u32 = undefined,
    BonePoses: [HandBone.max]Posef = undefined,
    BoneParentIndices: [HandBone.max]HandBoneIndex = undefined,
    Capsules: [HandBone.max_skinnable]BoneCapsule = undefined,
};
pub const HandSkeleton = HandSkeleton_V1;
pub const HandMeshHeader = extern struct {
    Version: HandVersion,
};
pub const HandMesh_V1 = extern struct {
    Header: HandMeshHeader = .{ .Version = .version_1 },
    NumVertices: u32 = 0,
    NumIndices: u32 = 0,
    Reserved: [13]u32 = undefined,
    VertexPositions: [HandConstants.max_vertices]Vector3f = undefined,
    Indices: [HandConstants.max_indices]VertexIndex = undefined,
    VertexNormals: [HandConstants.max_vertices]Vector3f = undefined,
    VertexUV0: [HandConstants.max_vertices]Vector2f = undefined,
    BlendIndices: [HandConstants.max_vertices]Vector4s = undefined,
    BlendWeights: [HandConstants.max_vertices]Vector4f = undefined,
};
pub const HandMesh = HandMesh_V1;

pub fn radiansFromDegrees(arg_deg: f32) f32 {
    var deg = arg_deg;
    return (deg * 3.1415927410125732) / 180.0;
}
pub fn degreesFromRadians(arg_rad: f32) f32 {
    var rad = arg_rad;
    return (rad * 180.0) / 3.1415927410125732;
}

pub fn getInterpupillaryDistance(tracking2: Tracking2) f32 {
    const leftPose = tracking2.Eye[Eye.left].ViewMatrix.inverse();
    const rightPose = tracking2.Eye[Eye.right].ViewMatrix.inverse();
    const delta = Vector3f{
        .x = rightPose.M[0][3] - leftPose.M[0][3],
        .y = rightPose.M[1][3] - leftPose.M[1][3],
        .z = rightPose.M[2][3] - leftPose.M[2][3],
    };
    return @sqrt(((delta.x * delta.x) + (delta.y * delta.y)) + (delta.z * delta.z));
}
pub fn getEyeHeight(eyeLevelTrackingPose: Posef, currentTrackingPose: Posef) f32 {
    return eyeLevelTrackingPose.Translation.y - currentTrackingPose.Translation.y;
}
pub fn getTransformFromPose(pose: Posef) Matrix4f {
    const rotation = Matrix4f.createFromQuaternion(pose.Orientation);
    const translation = Matrix4f.createTranslation(pose.Translation.x, pose.Translation.y, pose.Translation.z);
    return translation.multiply(rotation);
}
pub fn getCenterViewMatrix(leftEyeViewMatrix: Matrix4f, rightEyeViewMatrix: Matrix4f) Matrix4f {
    var centerViewMatrix: Matrix4f = leftEyeViewMatrix;
    centerViewMatrix.M[0][3] = (leftEyeViewMatrix.M[0][3] + rightEyeViewMatrix.M[0][3]) * 0.5;
    centerViewMatrix.M[1][3] = (leftEyeViewMatrix.M[1][3] + rightEyeViewMatrix.M[1][3]) * 0.5;
    centerViewMatrix.M[2][3] = (leftEyeViewMatrix.M[2][3] + rightEyeViewMatrix.M[2][3]) * 0.5;
    return centerViewMatrix;
}

// ----------------------- Deprecated APIs ------------------------

const deprecated_with_SubmitFrame = @compileError(
    "Deprecated: The vrapi_SubmitFrame2 path with flexible layer types should be used instead.",
);
pub const FrameLayerType = deprecated_with_SubmitFrame;
pub const FrameLayerTexture = deprecated_with_SubmitFrame;
pub const FrameLayer = deprecated_with_SubmitFrame;
pub const FrameParms = deprecated_with_SubmitFrame;
pub const PerformanceParms = deprecated_with_SubmitFrame;
pub const vrapi_SubmitFrame = deprecated_with_SubmitFrame;
pub const submitFrame = vrapi_SubmitFrame;

pub const vrapi_RecenterPose = @compileError(
    "vrapi_RecenterPose() is being deprecated because it is supported at the user " ++
    "level via system interaction, and at the app level, the app is free to use " ++
    "any means it likes to control the mapping of virtual space to physical space.",
);
pub const recenterPose = vrapi_RecenterPose;

const deprecated_tracking_transform = @compileError(
    "The TrackingTransform API has been deprecated because it was superceded by the " ++
    "TrackingSpace API. The key difference in the TrackingSpace API is that LOCAL " ++
    "and LOCAL_FLOOR spaces are mutable, so user/system recentering is transparently " ++
    "applied without app intervention.",
);
pub const vrapi_GetTrackingTransform = deprecated_tracking_transform;
pub const vrapi_SetTrackingTransform = deprecated_tracking_transform;
pub const getTrackingTransform = vrapi_GetTrackingTransform;
pub const setTrackingTransform = vrapi_SetTrackingTransform;

pub const InputGamepadCapabilities = @compileError("Deprecated");
pub const InputStateGamepad = @compileError("Deprecated");
pub const vrapi_RecenterInputPose = @compileError("Deprecated");
pub const recenterInputPose = vrapi_RecenterInputPose;

pub const showFatalError = vrapi_ShowFatalError;
pub const vrapi_ShowFatalError = @compileError("Deprecated: Display a Fatal Error Message using the System UI.");
