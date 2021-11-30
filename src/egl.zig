const std = @import("std");
const log = std.log.scoped(.egl);
pub const c = @import("c.zig");

const android = @import("android-support.zig");

pub const Version = enum {
    gles2,
    gles3,
};

pub const EGLContext = struct {
    const Self = @This();

    major_ver: c.EGLint,
    minor_ver: c.EGLint,
    display: c.EGLDisplay,
    tiny_surface: c.EGLSurface,
    context: c.EGLContext,

    pub fn init(version: Version) !Self {
        const EGLint = c.EGLint;

        var egl_display = c.eglGetDisplay(null);
        if (egl_display == null) {
            std.log.err("Error: No display found!\n", .{});
            return error.FailedToInitializeEGL;
        }

        var egl_major: EGLint = undefined;
        var egl_minor: EGLint = undefined;
        if (c.eglInitialize(egl_display, &egl_major, &egl_minor) == 0) {
            std.log.err("Error: eglInitialise failed!\n", .{});
            return error.FailedToInitializeEGL;
        }

        std.log.info(
            \\EGL Version:    {s}
            \\EGL Vendor:     {s}
            \\EGL Extensions: {s}
            \\
        , .{
            std.mem.span(c.eglQueryString(egl_display, c.EGL_VERSION)),
            std.mem.span(c.eglQueryString(egl_display, c.EGL_VENDOR)),
            std.mem.span(c.eglQueryString(egl_display, c.EGL_EXTENSIONS)),
        });

        const config_attribute_list = [_]EGLint{
            c.EGL_RED_SIZE,
            8,
            c.EGL_GREEN_SIZE,
            8,
            c.EGL_BLUE_SIZE,
            8,
            c.EGL_ALPHA_SIZE,
            8,
            c.EGL_BUFFER_SIZE,
            32,
            c.EGL_STENCIL_SIZE,
            0,
            c.EGL_DEPTH_SIZE,
            16,
            // c.EGL_SAMPLES, 1,
            c.EGL_RENDERABLE_TYPE,
            switch (version) {
                .gles3 => c.EGL_OPENGL_ES3_BIT,
                .gles2 => c.EGL_OPENGL_ES2_BIT,
            },
            c.EGL_NONE,
        };

        var config: c.EGLConfig = undefined;
        var num_config: c.EGLint = undefined;
        if (c.eglChooseConfig(egl_display, &config_attribute_list, &config, 1, &num_config) == c.EGL_FALSE) {
            std.log.err("Error: eglChooseConfig failed: 0x{X:0>4}\n", .{c.eglGetError()});
            return error.FailedToInitializeEGL;
        }

        std.log.info("Config: {}\n", .{num_config});

        const context_attribute_list = [_]EGLint{ c.EGL_CONTEXT_CLIENT_VERSION, 2, c.EGL_NONE };

        var context = c.eglCreateContext(egl_display, config, null, &context_attribute_list);
        if (context == null) {
            log.err("Error: eglCreateContext failed: 0x{X:0>4}\n", .{c.eglGetError()});
            return error.FailedToInitializeEGL;
        }
        errdefer _ = c.eglDestroyContext(egl_display, context);

        std.log.info("Context created: {}\n", .{context});

        // Oculus doesn't need an EGL surface for most things, but we need a surface
        // so that we can use eglMakeCurrent for the context.  Use a little tiny surface.
        const tiny_surface_attribs = [_]EGLint{ c.EGL_WIDTH, 16, c.EGL_HEIGHT, 16, c.EGL_NONE };
        const tiny_surface = c.eglCreatePbufferSurface(egl_display, config, &tiny_surface_attribs);
        if (tiny_surface == null) {
            log.err("Error: eglCreatePbufferSurface for tiny surface failed: 0x{X:0>4}\n", .{ c.eglGetError() });
            return error.FailedToInitializeEGL;
        }
        errdefer _ = c.eglDestroySurface(egl_display, tiny_surface);

        if (c.eglMakeCurrent(egl_display, tiny_surface, tiny_surface, context) == c.EGL_FALSE) {
            log.err("Error: eglMakeCurrent() failed: 0x{X:0>4}\n", .{ c.eglGetError() });
            return error.FailedToInitializeEGL;
        }

        return Self{
            .major_ver = egl_major,
            .minor_ver = egl_minor,
            .display = egl_display,
            .tiny_surface = tiny_surface,
            .context = context,
        };
    }

    pub fn deinit(self: *Self) void {
        self.release();
        _ = c.eglDestroySurface(self.display, self.tiny_surface);
        _ = c.eglDestroyContext(self.display, self.context);
        self.* = undefined;
    }

    pub fn makeCurrent(self: Self) !void {
        if (c.eglMakeCurrent(self.display, self.tiny_surface, self.tiny_surface, self.context) == c.EGL_FALSE) {
            std.log.err("Error: eglMakeCurrent failed: 0x{X:0>4}\n", .{c.eglGetError()});
            return error.EglFailure;
        }
    }

    pub fn release(self: Self) void {
        if (c.eglMakeCurrent(self.display, self.tiny_surface, self.tiny_surface, null) == c.EGL_FALSE) {
            std.log.err("Error: eglMakeCurrent for release failed: 0x{X:0>4}\n", .{c.eglGetError()});
        }
    }
};
