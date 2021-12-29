const std = @import("std");
const builtin = @import("builtin");
const Atomic = std.atomic.Atomic;

const android = @import("android");

pub const panic = android.panic;
pub const log = android.log;

const EGLContext = android.egl.EGLContext;
const JNI = android.JNI;
const c = android.egl.c;
const ovr = android.ovr;

const Allocator = std.mem.Allocator;
const c_allocator = std.heap.c_allocator;

const app_log = std.log.scoped(.app);

const check_gl_errors = std.debug.runtime_safety and true;
const num_multisamples = 4;
const initial_cpu_level = 2;
const initial_gpu_level = 3;

const colors = struct {
    pub const black = [4]u8{ 0, 0, 0, 255 };
    pub const red = [4]u8{ 255, 0, 0, 255 };
    pub const green = [4]u8{ 0, 255, 0, 255 };
    pub const blue = [4]u8{ 0, 0, 255, 255 };
    pub const magenta = [4]u8{ 255, 0, 255, 255 };
    pub const cyan = [4]u8{ 0, 255, 255, 255 };
    pub const yellow = [4]u8{ 255, 255, 0, 255 };
    pub const white = [4]u8{ 255, 255, 255, 255 };

    pub const purple = [4]u8{ 128, 0, 255, 255 };
    pub const seafoam = [4]u8{ 0, 255, 128, 255 };
    pub const orange = [4]u8{ 255, 128, 0, 255 };

    pub const chartreuse = [4]u8{ 128, 255, 0, 255 };
    pub const pink = [4]u8{ 255, 0, 128, 255 };
    pub const blue_cyan = [4]u8{ 0, 128, 255, 255 };

    pub const dignified_gray = [4]u8{ 51, 51, 51, 255 };
};

pub const Program = struct {
    const max_uniforms = 8;
    const max_textures = 8;

    program: c.GLuint = 0,
    vertex_shader: c.GLuint = 0,
    fragment_shader: c.GLuint = 0,

    uniform_locations: [max_uniforms]c.GLint = undefined,
    uniform_bindings: [max_uniforms]c.GLint = undefined,
    textures: [max_textures]c.GLint = undefined,

    const version_header = "#version 300 es\n";
    const enable_multiview = "#define DISABLE_MULTIVIEW 0\n";
    const disable_multiview = "#define DISABLE_MULTIVIEW 1\n";

    pub fn create(
        self: *Program,
        vertex_source: [:0]const u8,
        fragment_source: [:0]const u8,
        vertex_attributes: []const VertexAttribute,
        use_multiview: bool,
    ) !void {
        var status: c.GLint = 0;

        const vs = GL(c.glCreateShader(c.GL_VERTEX_SHADER), @src());
        errdefer GL(c.glDeleteShader(vs), @src());

        const vertex_sources = [_][*c]const u8{
            version_header,
            if (use_multiview) enable_multiview else disable_multiview,
            vertex_source.ptr,
        };
        GL(c.glShaderSource(vs, 3, &vertex_sources, 0), @src());
        GL(c.glCompileShader(vs), @src());
        GL(c.glGetShaderiv(vs, c.GL_COMPILE_STATUS, &status), @src());
        if (status == c.GL_FALSE) {
            var msg: [4096]c.GLchar = undefined;
            GL(c.glGetShaderInfoLog(vs, msg.len, 0, &msg), @src());
            const err_log = std.mem.sliceTo(&msg, 0);
            app_log.err("Failed to compile vertex shader!\nSource:\n{s}\n{s}\n", .{ vertex_source, err_log });
            return error.ShaderCreationFailed;
        }

        const fs = GL(c.glCreateShader(c.GL_FRAGMENT_SHADER), @src());
        errdefer GL(c.glDeleteShader(fs), @src());

        const fragment_sources = [_][*c]const u8{
            version_header,
            fragment_source.ptr,
        };
        GL(c.glShaderSource(fs, 2, &fragment_sources, 0), @src());
        GL(c.glCompileShader(fs), @src());
        GL(c.glGetShaderiv(fs, c.GL_COMPILE_STATUS, &status), @src());
        if (status == c.GL_FALSE) {
            var msg: [4096]c.GLchar = undefined;
            GL(c.glGetShaderInfoLog(fs, msg.len, 0, &msg), @src());
            const err_log = std.mem.sliceTo(&msg, 0);
            app_log.err("Failed to compile fragment shader!\nSource:\n{s}\n{s}\n", .{ vertex_source, err_log });
            return error.ShaderCreationFailed;
        }

        const program = GL(c.glCreateProgram(), @src());
        errdefer GL(c.glDeleteProgram(program), @src());
        GL(c.glAttachShader(program, vs), @src());
        GL(c.glAttachShader(program, fs), @src());

        for (vertex_attributes) |attr| {
            GL(c.glBindAttribLocation(program, attr.location, attr.name.ptr), @src());
        }

        GL(c.glLinkProgram(program), @src());
        GL(c.glGetProgramiv(program, c.GL_LINK_STATUS, &status), @src());
        if (status == c.GL_FALSE) {
            var msg: [4096]c.GLchar = undefined;
            GL(c.glGetProgramInfoLog(fs, msg.len, 0, &msg), @src());
            const err_log = std.mem.sliceTo(&msg, 0);
            app_log.err("Failed to link program!\n{s}\n", .{err_log});
            return error.ShaderCreationFailed;
        }

        var num_buffer_bindings: c_int = 0;

        // fetch uniform locations
        std.mem.set(c.GLint, &self.uniform_locations, -1);
        for (program_uniforms) |uniform| {
            if (uniform.kind == .buffer) {
                const location = GL(c.glGetUniformBlockIndex(program, uniform.name.ptr), @src());
                const binding = num_buffer_bindings;
                num_buffer_bindings += 1;
                GL(c.glUniformBlockBinding(program, location, @intCast(c_uint, binding)), @src());
                self.uniform_locations[uniform.index] = @intCast(c_int, location);
                self.uniform_bindings[uniform.index] = binding;
            } else {
                const location = GL(c.glGetUniformLocation(program, uniform.name.ptr), @src());
                self.uniform_locations[uniform.index] = location;
                self.uniform_bindings[uniform.index] = location;
            }
        }

        GL(c.glUseProgram(program), @src());

        // fetch texture locations
        for (self.textures) |*tex, i| {
            var buf: [32]u8 = undefined;
            const tex_name = std.fmt.bufPrintZ(&buf, "Texture{}", .{i}) catch unreachable;
            tex.* = GL(c.glGetUniformLocation(program, tex_name.ptr), @src());
            if (tex.* != -1) {
                GL(c.glUniform1i(tex.*, @intCast(c_int, i)), @src());
            }
        }

        GL(c.glUseProgram(0), @src());

        self.vertex_shader = vs;
        self.fragment_shader = fs;
        self.program = program;
    }

    pub fn destroy(self: *Program) void {
        if (self.program != 0) {
            GL(c.glDeleteProgram(self.program), @src());
            self.program = 0;
        }
        if (self.fragment_shader != 0) {
            GL(c.glDeleteShader(self.fragment_shader), @src());
            self.fragment_shader = 0;
        }
        if (self.vertex_shader != 0) {
            GL(c.glDeleteShader(self.vertex_shader), @src());
            self.vertex_shader = 0;
        }
    }
};

const vertex_shader_src =
    \\ #ifndef DISABLE_MULTIVIEW
    \\     #define DISABLE_MULTIVIEW 0
    \\ #endif
    \\ #define NUM_VIEWS 2
    \\ #if defined( GL_OVR_multiview2 ) && ! DISABLE_MULTIVIEW
    \\     #extension GL_OVR_multiview2 : enable
    \\     layout(num_views=NUM_VIEWS) in;
    \\     #define VIEW_ID gl_ViewID_OVR
    \\ #else
    \\     uniform lowp int ViewID;
    \\     #define VIEW_ID ViewID
    \\ #endif
    \\ in vec3 vertexPosition;
    \\ in vec4 vertexColor;
    \\ in mat4 vertexTransform;
    \\ uniform SceneMatrices
    \\ {
    \\     uniform mat4 ViewMatrix[NUM_VIEWS];
    \\     uniform mat4 ProjectionMatrix[NUM_VIEWS];
    \\ } sm;
    \\ out vec4 fragmentColor;
    \\ void main()
    \\ {
    \\     gl_Position = sm.ProjectionMatrix[VIEW_ID] * ( sm.ViewMatrix[VIEW_ID] * ( vertexTransform * vec4( vertexPosition * 0.1, 1.0 ) ) );
    \\     fragmentColor = vertexColor;
    \\ }
;
const fragment_shader_src =
    \\ in lowp vec4 fragmentColor;
    \\ out lowp vec4 outColor;
    \\ void main()
    \\ {
    \\     outColor = fragmentColor;
    \\ }
;

pub const Uniform = struct {
    pub const view_id = 0;
    pub const scene_matrices = 1;

    index: u8,
    kind: enum {
        vector4,
        matrix4x4,
        int,
        buffer,
    },
    name: [:0]const u8,
};

pub const program_uniforms = [_]Uniform{
    .{ .index = Uniform.view_id, .kind = .int, .name = "ViewID" },
    .{ .index = Uniform.scene_matrices, .kind = .buffer, .name = "SceneMatrices" },
};

pub const VertexAttribute = struct {
    location: u32,
    name: [:0]const u8,
};

pub const VertexAttribPointer = struct {
    index: c.GLuint,
    size: c.GLint,
    kind: c.GLenum,
    normalized: c.GLboolean,
    stride: c.GLsizei,
    pointer: ?*const anyopaque,
};

pub const Geometry = struct {
    const max_vertex_attrib_pointers = 3;

    // Vertex attribute bindings
    pub const va_position = 0;
    pub const va_color = 1;
    pub const va_uv = 2;
    pub const va_transform = 3;

    pub const program_vertex_attributes = [_]VertexAttribute{
        .{ .location = va_position, .name = "vertexPosition" },
        .{ .location = va_color, .name = "vertexColor" },
        .{ .location = va_uv, .name = "vertexUv" },
        .{ .location = va_transform, .name = "vertexTransform" },
    };

    vertex_buffer: c.GLuint = 0,
    index_buffer: c.GLuint = 0,
    vertex_array_object: c.GLuint = 0,
    vertex_count: u32 = 0,
    index_count: u32 = 0,
    vertex_attribs: []const VertexAttribPointer = &.{},

    pub fn createCube(self: *Geometry) void {
        const CubeVertices = extern struct {
            positions: [8][4]i8,
            colors: [8][4]u8,
        };
        // zig fmt: off
        const cube_vertices = CubeVertices{
            .positions = .{
                .{-127,  127, -127,  127},
                .{ 127,  127, -127,  127},
                .{ 127,  127,  127,  127},
                .{-127,  127,  127,  127}, // top
                .{-127, -127, -127,  127},
                .{-127, -127,  127,  127},
                .{ 127, -127,  127,  127},
                .{ 127, -127, -127,  127}, // bottom
            },
            .colors = .{
                .{  0, 255,   0, 255},
                .{255, 255,   0, 255},
                .{255, 255, 255, 255},
                .{  0, 255, 255, 255},
                .{  0,   0,   0, 255},
                .{  0,   0, 255, 255},
                .{255,   0, 255, 255},
                .{255,   0,   0, 255},
            },
        };

        const cube_indices = [36]u16{
            0, 2, 1, 2, 0, 3, // top
            4, 6, 5, 6, 4, 7, // bottom
            2, 6, 7, 7, 1, 2, // right
            0, 4, 5, 5, 3, 0, // left
            3, 5, 6, 6, 2, 3, // front
            0, 1, 7, 7, 4, 0, // back
        };
        // zig fmt: on

        self.vertex_count = 8;
        self.index_count = 36;

        const cube_vertex_attrs = comptime [_]VertexAttribPointer{ .{
            .index = va_position,
            .size = 4,
            .kind = c.GL_BYTE,
            .normalized = 1,
            .stride = @sizeOf([4]i8),
            .pointer = @intToPtr(?*const anyopaque, @offsetOf(CubeVertices, "positions")),
        }, .{
            .index = va_color,
            .size = 4,
            .kind = c.GL_UNSIGNED_BYTE,
            .normalized = 1,
            .stride = @sizeOf([4]u8),
            .pointer = @intToPtr(?*const anyopaque, @offsetOf(CubeVertices, "colors")),
        } };
        self.vertex_attribs = &cube_vertex_attrs;

        var vb: c.GLuint = undefined;
        GL(c.glGenBuffers(1, &vb), @src());
        self.vertex_buffer = vb;

        GL(c.glBindBuffer(c.GL_ARRAY_BUFFER, vb), @src());
        GL(c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(CubeVertices), &cube_vertices, c.GL_STATIC_DRAW), @src());
        GL(c.glBindBuffer(c.GL_ARRAY_BUFFER, 0), @src());

        var ib: c.GLuint = undefined;
        GL(c.glGenBuffers(1, &ib), @src());
        self.index_buffer = ib;

        GL(c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ib), @src());
        GL(c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(cube_indices)), &cube_indices, c.GL_STATIC_DRAW), @src());
        GL(c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, 0), @src());
    }

    pub fn destroy(self: *Geometry) void {
        GL(c.glDeleteBuffers(1, &self.index_buffer), @src());
        GL(c.glDeleteBuffers(1, &self.vertex_buffer), @src());
        self.* = .{};
    }

    pub fn createVAO(self: *Geometry) void {
        var vao: c.GLuint = undefined;
        GL(c.glGenVertexArrays(1, &vao), @src());
        self.vertex_array_object = vao;

        GL(c.glBindVertexArray(vao), @src());
        GL(c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, self.index_buffer), @src());

        setUpBuffer(vao, self.vertex_buffer, self.vertex_attribs, false);
    }

    pub fn destroyVAO(self: *Geometry) void {
        GL(c.glDeleteVertexArrays(1, &self.vertex_array_object), @src());
    }
};

pub const Framebuffer = struct {
    width: c_int,
    height: c_int,
    multisamples: u32,
    texture_swapchain_length: u32,
    texture_swapchain_index: u32,
    use_multiview: bool,
    color_texture_swapchain: *ovr.TextureSwapChain,
    depth_buffers: []c.GLuint,
    frame_buffers: []c.GLuint,

    pub fn init(
        try_use_multiview: bool,
        color_format: c.GLenum,
        width: c_int,
        height: c_int,
        multisamples: c_int,
        allocator: Allocator,
    ) !Framebuffer {
        const glRenderbufferStorageMultisampleEXT =
            glext.getProc(glext.glRenderbufferStorageMultisampleEXT);
        const glFramebufferTexture2DMultisampleEXT =
            glext.getProc(glext.glFramebufferTexture2DMultisampleEXT);
        const glFramebufferTextureMultiviewOVR =
            glext.getProc(glext.glFramebufferTextureMultiviewOVR);
        const glFramebufferTextureMultisampleMultiviewOVR =
            glext.getProc(glext.glFramebufferTextureMultisampleMultiviewOVR);

        const use_multiview = try_use_multiview and glFramebufferTextureMultiviewOVR != null;

        const swapchain = ovr.TextureSwapChain.create3(
            if (use_multiview) .@"2d_array" else .@"2d",
            color_format,
            width,
            height,
            1, // levels
            3, // buffer count
        ) orelse {
            app_log.err("CreateTextureSwapChain3 failed!\n", .{});
            return error.FramebufferCreateFailed;
        };
        errdefer swapchain.destroy();

        const length = swapchain.getLength();

        const depth_buffers = try allocator.alloc(c.GLuint, @intCast(usize, length));
        errdefer allocator.free(depth_buffers);

        const frame_buffers = try allocator.alloc(c.GLuint, @intCast(usize, length));
        errdefer allocator.free(frame_buffers);

        if (use_multiview) {
            GL(c.glGenTextures(length, depth_buffers.ptr), @src());
        } else {
            GL(c.glGenRenderbuffers(length, depth_buffers.ptr), @src());
        }
        errdefer if (use_multiview) {
            GL(c.glDeleteTextures(length, depth_buffers.ptr), @src());
        } else {
            GL(c.glDeleteRenderbuffers(length, depth_buffers.ptr), @src());
        };

        GL(c.glGenFramebuffers(length, frame_buffers.ptr), @src());
        errdefer GL(c.glDeleteFramebuffers(length, frame_buffers.ptr), @src());

        var i: u32 = 0;
        while (i < @intCast(u32, length)) : (i += 1) {
            const color_tex = swapchain.getHandle(@intCast(c_int, i));

            // set up render target params
            {
                const target = if (use_multiview) c.GL_TEXTURE_2D_ARRAY else c.GL_TEXTURE_2D;
                const utarget = @intCast(c.GLuint, target);
                GL(c.glBindTexture(utarget, color_tex), @src());
                GL(c.glTexParameteri(utarget, c.GL_TEXTURE_WRAP_S, glext.GL_CLAMP_TO_BORDER), @src());
                GL(c.glTexParameteri(utarget, c.GL_TEXTURE_WRAP_T, glext.GL_CLAMP_TO_BORDER), @src());
                const borderColor = std.mem.zeroes([4]c.GLfloat);
                GL(c.glTexParameterfv(utarget, glext.GL_TEXTURE_BORDER_COLOR, &borderColor), @src());
                GL(c.glTexParameteri(utarget, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR), @src());
                GL(c.glTexParameteri(utarget, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR), @src());
                GL(c.glBindTexture(utarget, 0), @src());
            }

            if (use_multiview) {
                // create depth buffer
                GL(c.glBindTexture(c.GL_TEXTURE_2D_ARRAY, depth_buffers[i]), @src());
                GL(c.glTexStorage3D(c.GL_TEXTURE_2D_ARRAY, 1, c.GL_DEPTH_COMPONENT24, width, height, 2), @src());
                GL(c.glBindTexture(c.GL_TEXTURE_2D_ARRAY, 0), @src());

                // create frame buffer
                GL(c.glBindFramebuffer(c.GL_DRAW_FRAMEBUFFER, frame_buffers[i]), @src());
                if (multisamples > 1 and glFramebufferTextureMultisampleMultiviewOVR != null) {
                    GL(glFramebufferTextureMultisampleMultiviewOVR.?(
                        c.GL_DRAW_FRAMEBUFFER,
                        c.GL_DEPTH_ATTACHMENT,
                        depth_buffers[i],
                        0, // level
                        multisamples,
                        0, // base view index
                        2, // num views
                    ), @src());
                    GL(glFramebufferTextureMultisampleMultiviewOVR.?(
                        c.GL_DRAW_FRAMEBUFFER,
                        c.GL_COLOR_ATTACHMENT0,
                        color_tex,
                        0, // level
                        multisamples,
                        0, // base view index
                        2, // num views
                    ), @src());
                } else {
                    GL(glFramebufferTextureMultiviewOVR.?(
                        c.GL_DRAW_FRAMEBUFFER,
                        c.GL_DEPTH_ATTACHMENT,
                        depth_buffers[i],
                        0, // level
                        0, // base view index
                        2, // num views
                    ), @src());
                    GL(glFramebufferTextureMultiviewOVR.?(
                        c.GL_DRAW_FRAMEBUFFER,
                        c.GL_COLOR_ATTACHMENT0,
                        color_tex,
                        0, // level
                        0, // base view index
                        2, // num views
                    ), @src());
                }

                const render_framebuffer_status =
                    GL(c.glCheckFramebufferStatus(c.GL_DRAW_FRAMEBUFFER), @src());
                GL(c.glBindFramebuffer(c.GL_DRAW_FRAMEBUFFER, 0), @src());

                if (render_framebuffer_status != c.GL_FRAMEBUFFER_COMPLETE) {
                    app_log.err(
                        "Incomplete frame buffer object: {s}\n",
                        .{glFramebufferStatusString(render_framebuffer_status)},
                    );
                    return error.FramebufferCreateFailed;
                }
            } else {
                if (multisamples > 1 and glRenderbufferStorageMultisampleEXT != null and glFramebufferTexture2DMultisampleEXT != null) {
                    // create multisampled depth buffer.
                    GL(c.glBindRenderbuffer(c.GL_RENDERBUFFER, depth_buffers[i]), @src());
                    GL(glRenderbufferStorageMultisampleEXT.?(c.GL_RENDERBUFFER, multisamples, c.GL_DEPTH_COMPONENT24, width, height), @src());
                    GL(c.glBindRenderbuffer(c.GL_RENDERBUFFER, 0), @src());

                    // create the frame buffer.
                    // NOTE: glFramebufferTexture2DMultisampleEXT only works with c.GL_FRAMEBUFFER.
                    GL(c.glBindFramebuffer(c.GL_FRAMEBUFFER, frame_buffers[i]), @src());
                    GL(glFramebufferTexture2DMultisampleEXT.?(
                        c.GL_FRAMEBUFFER,
                        c.GL_COLOR_ATTACHMENT0,
                        c.GL_TEXTURE_2D,
                        color_tex,
                        0, // level
                        multisamples,
                    ), @src());
                    GL(c.glFramebufferRenderbuffer(
                        c.GL_FRAMEBUFFER,
                        c.GL_DEPTH_ATTACHMENT,
                        c.GL_RENDERBUFFER,
                        depth_buffers[i],
                    ), @src());
                    const render_framebuffer_status =
                        GL(c.glCheckFramebufferStatus(c.GL_FRAMEBUFFER), @src());
                    GL(c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0), @src());

                    if (render_framebuffer_status != c.GL_FRAMEBUFFER_COMPLETE) {
                        app_log.err(
                            "Incomplete frame buffer object: {s}\n",
                            .{glFramebufferStatusString(render_framebuffer_status)},
                        );
                        return error.FramebufferCreateFailed;
                    }
                } else {
                    GL(c.glBindRenderbuffer(c.GL_RENDERBUFFER, depth_buffers[i]), @src());
                    GL(c.glRenderbufferStorage(c.GL_RENDERBUFFER, c.GL_DEPTH_COMPONENT24, width, height), @src());
                    GL(c.glBindRenderbuffer(c.GL_RENDERBUFFER, 0), @src());

                    GL(c.glBindFramebuffer(c.GL_DRAW_FRAMEBUFFER, frame_buffers[i]), @src());
                    GL(c.glFramebufferRenderbuffer(
                        c.GL_DRAW_FRAMEBUFFER,
                        c.GL_DEPTH_ATTACHMENT,
                        c.GL_RENDERBUFFER,
                        depth_buffers[i],
                    ), @src());
                    GL(c.glFramebufferTexture2D(
                        c.GL_DRAW_FRAMEBUFFER,
                        c.GL_COLOR_ATTACHMENT0,
                        c.GL_TEXTURE_2D,
                        color_tex,
                        0,
                    ), @src());
                    const render_framebuffer_status = GL(c.glCheckFramebufferStatus(c.GL_DRAW_FRAMEBUFFER), @src());
                    GL(c.glBindFramebuffer(c.GL_DRAW_FRAMEBUFFER, 0), @src());
                    if (render_framebuffer_status != c.GL_FRAMEBUFFER_COMPLETE) {
                        app_log.err(
                            "Incomplete frame buffer object: {s}\n",
                            .{glFramebufferStatusString(render_framebuffer_status)},
                        );
                        return error.FramebufferCreateFailed;
                    }
                }
            }
        }

        return Framebuffer{
            .width = width,
            .height = height,
            .multisamples = @intCast(u32, multisamples),
            .texture_swapchain_length = @intCast(u32, length),
            .texture_swapchain_index = 0,
            .use_multiview = use_multiview,
            .color_texture_swapchain = swapchain,
            .depth_buffers = depth_buffers,
            .frame_buffers = frame_buffers,
        };
    }

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        GL(c.glDeleteFramebuffers(@intCast(c_int, self.texture_swapchain_length), self.frame_buffers.ptr), @src());
        if (self.use_multiview) {
            GL(c.glDeleteTextures(@intCast(c_int, self.texture_swapchain_length), self.depth_buffers.ptr), @src());
        } else {
            GL(c.glDeleteRenderbuffers(@intCast(c_int, self.texture_swapchain_length), self.depth_buffers.ptr), @src());
        }
        self.color_texture_swapchain.destroy();

        allocator.free(self.depth_buffers);
        allocator.free(self.frame_buffers);

        self.* = undefined;
    }

    pub fn setCurrent(self: *@This()) void {
        GL(c.glBindFramebuffer(c.GL_DRAW_FRAMEBUFFER, self.frame_buffers[self.texture_swapchain_index]), @src());
    }

    pub fn setNone() void {
        GL(c.glBindFramebuffer(c.GL_DRAW_FRAMEBUFFER, 0), @src());
    }

    pub fn resolve(self: *@This()) void {
        _ = self;
        // discard the depth buffer, so the tiler won't need to write it back out to memory.
        const depth_attachment = [_]c.GLenum{c.GL_DEPTH_ATTACHMENT};
        GL(c.glInvalidateFramebuffer(c.GL_DRAW_FRAMEBUFFER, 1, &depth_attachment), @src());

        // we now let the resolve happen implicitly.
    }

    pub fn advance(self: *@This()) void {
        const next = self.texture_swapchain_index + 1;
        self.texture_swapchain_index = if (next >= self.texture_swapchain_length) 0 else next;
    }
};

fn setUpBuffer(vao: c.GLuint, buffer: c.GLuint, attributes: []const VertexAttribPointer, instanced: bool) void {
    GL(c.glBindVertexArray(vao), @src());
    GL(c.glBindBuffer(c.GL_ARRAY_BUFFER, buffer), @src());
    for (attributes) |*attr| {
        GL(c.glEnableVertexAttribArray(attr.index), @src());
        GL(c.glVertexAttribPointer(
            attr.index,
            attr.size,
            attr.kind,
            attr.normalized,
            attr.stride,
            attr.pointer,
        ), @src());
        if (instanced) {
            GL(c.glVertexAttribDivisor(attr.index, 1), @src());
        }
    }
    GL(c.glBindVertexArray(0), @src());
}

const Scene = struct {
    const num_instances = 1500;
    const num_rotations = 16;

    created: bool = false,
    created_vaos: bool = false,
    random: u32 = 2,
    program: Program = .{},
    cube: Geometry = .{},
    scene_matrices: c.GLuint = 0,
    instance_transform_buffer: c.GLuint = 0,
    rotations: [num_rotations]ovr.Vector3f = undefined,
    cube_positions: [num_instances]ovr.Vector3f = undefined,
    cube_rotations: [num_instances]u32 = undefined,

    debug_line_program: Program = .{},
    debug_line_instance_buffer: c.GLuint = 0,
    debug_lines: std.ArrayListUnmanaged(DebugLine) = .{},
    debug_line_vao: c.GLuint = 0,

    pub fn isCreated(self: *const Scene) bool {
        return self.created;
    }

    pub fn create(self: *Scene, use_multiview: bool) !void {
        @setCold(true);

        try self.program.create(
            vertex_shader_src,
            fragment_shader_src,
            &Geometry.program_vertex_attributes,
            use_multiview,
        );
        errdefer self.program.destroy();

        self.cube.createCube();
        errdefer self.cube.destroy();

        // create the transform buffer, empty
        GL(c.glGenBuffers(1, &self.instance_transform_buffer), @src());
        GL(c.glBindBuffer(c.GL_ARRAY_BUFFER, self.instance_transform_buffer), @src());
        GL(c.glBufferData(c.GL_ARRAY_BUFFER, num_instances * 4 * 4 * @sizeOf(f32), null, c.GL_DYNAMIC_DRAW), @src());
        GL(c.glBindBuffer(c.GL_ARRAY_BUFFER, 0), @src());

        // create the scene matrices uniform buffer
        GL(c.glGenBuffers(1, &self.scene_matrices), @src());
        GL(c.glBindBuffer(c.GL_UNIFORM_BUFFER, self.scene_matrices), @src());
        GL(c.glBufferData(c.GL_UNIFORM_BUFFER, 4 * @sizeOf(ovr.Matrix4f), null, c.GL_STATIC_DRAW), @src());
        GL(c.glBindBuffer(c.GL_UNIFORM_BUFFER, 0), @src());

        // randomize rotations
        for (self.rotations) |*angles| {
            angles.* = .{
                .x = self.randomFloat(),
                .y = self.randomFloat(),
                .z = self.randomFloat(),
            };
        }

        // find lots of cubes
        const spawn_size = 5.0 + 0.1 * @sqrt(@intToFloat(f32, num_instances));
        const close = 0.4;
        var distances_sqr: [num_instances]f32 = undefined;
        for (self.cube_positions) |_, i| {
            const pos = while (true) {
                // pick a random position
                const rx = (self.randomFloat() - 0.5) * spawn_size;
                const ry = (self.randomFloat() - 0.5) * spawn_size;
                const rz = (self.randomFloat() - 0.5) * spawn_size;
                const abs = std.math.absFloat;
                if (abs(rx) >= close and abs(ry) >= close and abs(rz) >= close) {
                    // check for overlaps with other cubes
                    for (self.cube_positions[0..i]) |other| {
                        if (abs(rx - other.x) < close and abs(ry - other.y) < close and abs(rz - other.z) < close) {
                            break;
                        }
                    } else break ovr.Vector3f.init(rx, ry, rz);
                }
            } else unreachable;

            // keep the list of cubes sorted by distance from the origin
            const dist_sqr = pos.x * pos.x + pos.y * pos.y + pos.z * pos.z;
            var j = i;
            while (j > 0) : (j -= 1) {
                if (dist_sqr > distances_sqr[j - 1]) break;
                distances_sqr[j] = distances_sqr[j - 1];
                self.cube_positions[j] = self.cube_positions[j - 1];
                self.cube_rotations[j] = self.cube_rotations[j - 1];
            }

            distances_sqr[j] = dist_sqr;
            self.cube_positions[j] = pos;
            self.cube_rotations[j] = @floatToInt(u32, self.randomFloat() * (num_rotations - 0.1));
        }

        try self.debug_line_program.create(
            DebugLine.vert_shader,
            DebugLine.frag_shader,
            &DebugLine.vertex_attrs,
            use_multiview,
        );
        errdefer self.debug_line_program.destroy();

        {
            var line_instance_buf: c.GLuint = 0;
            GL(c.glGenBuffers(1, &line_instance_buf), @src());
            self.debug_line_instance_buffer = line_instance_buf;
        }

        self.created = true;

        self.createVAOs();
    }

    pub fn destroy(self: *Scene) void {
        self.destroyVAOs();

        self.program.destroy();
        self.cube.destroy();
        GL(c.glDeleteBuffers(1, &self.instance_transform_buffer), @src());
        GL(c.glDeleteBuffers(1, &self.scene_matrices), @src());

        self.debug_line_program.destroy();
        GL(c.glDeleteBuffers(1, &self.debug_line_instance_buffer), @src());

        self.debug_lines.deinit(c_allocator);

        self.created = false;
    }

    pub fn createVAOs(self: *Scene) void {
        if (self.created_vaos) return;

        // Init cube VAO
        {
            self.cube.createVAO();

            var geometry_instance_layout = [_]VertexAttribPointer{.{
                .index = undefined,
                .size = 4,
                .kind = c.GL_FLOAT,
                .normalized = c.GL_FALSE,
                .stride = @sizeOf(ovr.Matrix4f),
                .pointer = undefined,
            }} ** 4;
            for (geometry_instance_layout) |*layout, i| {
                layout.index = Geometry.va_transform + @intCast(c.GLuint, i);
                layout.pointer = @intToPtr(?*anyopaque, i * @sizeOf(ovr.Vector4f));
            }
            setUpBuffer(
                self.cube.vertex_array_object,
                self.instance_transform_buffer,
                &geometry_instance_layout,
                true, // instanced
            );
        }

        // Init debug line VAO
        {
            var vao: c.GLuint = undefined;
            GL(c.glGenVertexArrays(1, &vao), @src());
            self.debug_line_vao = vao;

            setUpBuffer(
                vao,
                self.debug_line_instance_buffer,
                &DebugLine.va_ptrs,
                true, // instanced
            );
        }

        self.created_vaos = true;
    }

    pub fn destroyVAOs(self: *Scene) void {
        if (!self.created_vaos) return;

        self.cube.destroyVAO();

        GL(c.glDeleteVertexArrays(1, &self.debug_line_vao), @src());

        self.created_vaos = false;
    }

    pub fn randomFloat(self: *Scene) f32 {
        self.random = 1664525 *% self.random +% 1013904223;
        const bits = 0x3f800000 | (self.random & 0x007FFFFF);
        return @bitCast(f32, bits) - 1.0;
    }

    pub fn drawDebugLine(self: *Scene, start: ovr.Vector3f, end: ovr.Vector3f, color: [4]u8) void {
        self.debug_lines.append(c_allocator, .{
            .start = start,
            .end = end,
            .color = color,
        }) catch |err| {
            std.debug.assert(err == error.OutOfMemory);
            app_log.warn("Failed to allocate memory for debug lines, size={}", .{self.debug_lines.capacity});
        };
    }
};

const Sound = struct {

};

const glext = struct {
    const GLCC: std.builtin.CallingConvention =
        if (builtin.os.tag == .windows) std.os.windows.WINAPI else .C;

    const ExtFunc = struct {
        name: [:0]const u8,
        Signature: type,
    };

    pub fn getProc(comptime func: ExtFunc) ?func.Signature {
        const proc = @ptrCast(?func.Signature, c.eglGetProcAddress(func.name.ptr));
        if (proc == null) {
            app_log.warn("Failed to load egl function {s}\n", .{func.name});
        }
        return proc;
    }

    pub const glRenderbufferStorageMultisampleEXT = ExtFunc{
        .name = "glRenderbufferStorageMultisampleEXT",
        .Signature = fn (
            target: c.GLenum,
            samples: c.GLsizei,
            internalformat: c.GLenum,
            width: c.GLsizei,
            height: c.GLsizei,
        ) callconv(GLCC) void,
    };

    pub const glFramebufferTexture2DMultisampleEXT = ExtFunc{
        .name = "glFramebufferTexture2DMultisampleEXT",
        .Signature = fn (
            target: c.GLenum,
            attachment: c.GLenum,
            textarget: c.GLenum,
            texture: c.GLuint,
            level: c.GLint,
            samples: c.GLsizei,
        ) callconv(GLCC) void,
    };

    pub const GL_CLAMP_TO_BORDER = 0x812D;
    pub const GL_TEXTURE_BORDER_COLOR = 0x1004;
    pub const GL_FRAMEBUFFER_SRGB_EXT: c.GLenum = 0x8DB9;
    pub const GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_NUM_VIEWS_OVR: c.GLenum = 0x9630;
    pub const GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_BASE_VIEW_INDEX_OVR: c.GLenum = 0x9632;
    pub const GL_MAX_VIEWS_OVR: c.GLenum = 0x9631;

    pub const glFramebufferTextureMultiviewOVR = ExtFunc{
        .name = "glFramebufferTextureMultiviewOVR",
        .Signature = fn (
            target: c.GLenum,
            attachment: c.GLenum,
            texture: c.GLuint,
            level: c.GLint,
            base_view_index: c.GLint,
            num_views: c.GLsizei,
        ) callconv(GLCC) void,
    };

    pub const glFramebufferTextureMultisampleMultiviewOVR = ExtFunc{
        .name = "glFramebufferTextureMultisampleMultiviewOVR",
        .Signature = fn (
            target: c.GLenum,
            attachment: c.GLenum,
            texture: c.GLuint,
            level: c.GLint,
            samples: c.GLsizei,
            base_view_index: c.GLint,
            num_views: c.GLsizei,
        ) callconv(GLCC) void,
    };
};

const events = struct {
    pub const resumed_bit = 1 << 0;
    pub const window_bit = 1 << 1;
    pub const configuration_bit = 1 << 2;
};

const DebugLine = extern struct {
    start: ovr.Vector3f,
    end: ovr.Vector3f,
    color: [4]u8,

    const va_start = 0;
    const va_end = 1;
    const va_color = 2;

    const vertex_attrs = [_]VertexAttribute{
        .{ .location = va_start, .name = "startPosition" },
        .{ .location = va_end, .name = "endPosition" },
        .{ .location = va_color, .name = "vertexColor" },
    };

    const va_ptrs = [_]VertexAttribPointer{
        .{
            .index = va_start,
            .size = 3,
            .kind = c.GL_FLOAT,
            .normalized = c.GL_FALSE,
            .stride = @sizeOf(DebugLine),
            .pointer = @intToPtr(?*anyopaque, @offsetOf(DebugLine, "start")),
        },
        .{
            .index = va_end,
            .size = 3,
            .kind = c.GL_FLOAT,
            .normalized = c.GL_FALSE,
            .stride = @sizeOf(DebugLine),
            .pointer = @intToPtr(?*anyopaque, @offsetOf(DebugLine, "end")),
        },
        .{
            .index = va_color,
            .size = 4,
            .kind = c.GL_UNSIGNED_BYTE,
            .normalized = c.GL_TRUE,
            .stride = @sizeOf(DebugLine),
            .pointer = @intToPtr(?*anyopaque, @offsetOf(DebugLine, "color")),
        },
    };

    const vert_shader =
        \\ #ifndef DISABLE_MULTIVIEW
        \\     #define DISABLE_MULTIVIEW 0
        \\ #endif
        \\ #define NUM_VIEWS 2
        \\ #if defined( GL_OVR_multiview2 ) && ! DISABLE_MULTIVIEW
        \\     #extension GL_OVR_multiview2 : enable
        \\     layout(num_views=NUM_VIEWS) in;
        \\     #define VIEW_ID gl_ViewID_OVR
        \\ #else
        \\     uniform lowp int ViewID;
        \\     #define VIEW_ID ViewID
        \\ #endif
        \\ in vec3 startPosition;
        \\ in vec3 endPosition;
        \\ in vec4 vertexColor;
        \\ uniform SceneMatrices
        \\ {
        \\     uniform mat4 ViewMatrix[NUM_VIEWS];
        \\     uniform mat4 ProjectionMatrix[NUM_VIEWS];
        \\ } sm;
        \\ out vec4 fragmentColor;
        \\ void main()
        \\ {
        \\     vec3 vertexPosition = (gl_VertexID == 0) ? startPosition : endPosition;
        \\     gl_Position = sm.ProjectionMatrix[VIEW_ID] * ( sm.ViewMatrix[VIEW_ID] * vec4( vertexPosition, 1.0 ) );
        \\     fragmentColor = vertexColor;
        \\ }
    ;
    const frag_shader = fragment_shader_src;
};

/// Entry point for our application.
/// This struct provides the interface to the android support package.
pub const AndroidApp = struct {
    const Self = @This();

    activity: *android.ANativeActivity,

    thread: ?std.Thread = null,

    config: *android.AConfiguration = undefined,

    event_mutex: std.Thread.Mutex = .{},
    event_window: ?*android.ANativeWindow = null,
    event_resumed: bool = false,
    event_config_changed: bool = false,

    running: Atomic(bool) = .{ .value = true },

    java: ovr.Java = undefined,
    use_multiview: bool = true,
    egl: EGLContext = undefined,
    vr: ?*ovr.Mobile = null,
    cpu_level: i32 = initial_cpu_level,
    gpu_level: i32 = initial_gpu_level,
    main_thread_tid: u32 = 0,
    renderer_thread_tid: u32 = 0,

    swap_interval: u32 = 1,
    frame_index: u64 = 1,
    display_time: f64 = 0,

    rotation: ovr.Vector3f = ovr.Vector3f.zero,

    scene: Scene = .{},

    framebuffers: [ovr.Eye.count]Framebuffer = undefined,
    num_buffers: u32 = 0,

    /// This is the entry point which initializes a application
    /// that has stored its previous state.
    /// `stored_state` is that state, the memory is only valid for this function.
    /// This function is run on the event thread.
    pub fn init(allocator: Allocator, activity: *android.ANativeActivity, stored_state: ?[]const u8) !Self {
        _ = allocator;
        _ = stored_state;

        return Self{
            .activity = activity,
        };
    }

    /// This function is called when the application is successfully initialized.
    /// It should create a background thread that processes the events and runs until
    /// the application gets destroyed.
    /// This function is run on the event thread.
    pub fn start(self: *Self) !void {
        self.thread = try std.Thread.spawn(.{}, mainLoop, .{self});
    }

    /// Uninitialize the application.
    /// Don't forget to stop your background thread here!
    /// This function is run on the event thread.
    pub fn deinit(self: *Self) void {
        self.running.store(false, .SeqCst);
        if (self.thread) |thread| {
            thread.join();
        }
        self.* = undefined;
    }

    pub fn onStart(self: *Self) void {
        _ = self;
        app_log.info("onStart()", .{});
    }

    pub fn onResume(self: *Self) void {
        app_log.info("onResume()", .{});

        self.event_mutex.lock();
        defer self.event_mutex.unlock();
        self.event_resumed = true;
    }

    pub fn onPause(self: *Self) void {
        app_log.info("onPause()", .{});

        self.event_mutex.lock();
        defer self.event_mutex.unlock();
        self.event_resumed = false;
    }

    pub fn onNativeWindowCreated(self: *Self, window: *android.ANativeWindow) void {
        app_log.info("onNativeWindowCreated({*})", .{window});

        self.event_mutex.lock();
        defer self.event_mutex.unlock();
        self.event_window = window;
    }

    pub fn onNativeWindowDestroyed(self: *Self, window: *android.ANativeWindow) void {
        app_log.info("onNativeWindowDestroyed({*})", .{window});

        self.event_mutex.lock();
        defer self.event_mutex.unlock();
        self.event_window = null;
    }

    pub fn onConfigurationChanged(self: *Self) void {
        app_log.info("onConfigurationChanged()", .{});

        self.event_mutex.lock();
        defer self.event_mutex.unlock();
        self.event_config_changed = true;
    }

    fn printConfig(config: *android.AConfiguration) void {
        var lang: [2]u8 = undefined;
        var country: [2]u8 = undefined;

        android.AConfiguration_getLanguage(config, &lang);
        android.AConfiguration_getCountry(config, &country);

        app_log.debug(
            \\MCC:         {}
            \\MNC:         {}
            \\Language:    {s}
            \\Country:     {s}
            \\Orientation: {}
            \\Touchscreen: {}
            \\Density:     {}
            \\Keyboard:    {}
            \\Navigation:  {}
            \\KeysHidden:  {}
            \\NavHidden:   {}
            \\SdkVersion:  {}
            \\ScreenSize:  {}
            \\ScreenLong:  {}
            \\UiModeType:  {}
            \\UiModeNight: {}
            \\
        , .{
            android.AConfiguration_getMcc(config),
            android.AConfiguration_getMnc(config),
            &lang,
            &country,
            android.AConfiguration_getOrientation(config),
            android.AConfiguration_getTouchscreen(config),
            android.AConfiguration_getDensity(config),
            android.AConfiguration_getKeyboard(config),
            android.AConfiguration_getNavigation(config),
            android.AConfiguration_getKeysHidden(config),
            android.AConfiguration_getNavHidden(config),
            android.AConfiguration_getSdkVersion(config),
            android.AConfiguration_getScreenSize(config),
            android.AConfiguration_getScreenLong(config),
            android.AConfiguration_getUiModeType(config),
            android.AConfiguration_getUiModeNight(config),
        });
    }

    fn getTimeInSeconds() f64 {
        var ts: std.os.timespec = undefined;
        std.os.clock_gettime(std.os.CLOCK.MONOTONIC, &ts) catch return 0;
        return (@intToFloat(f64, ts.tv_sec) * 1e9 + @intToFloat(f64, ts.tv_nsec)) * 1e-9;
    }

    fn handleAndroidEvents(self: *Self) void {
        self.event_mutex.lock();
        defer self.event_mutex.unlock();

        if (self.event_config_changed) {
            android.AConfiguration_fromAssetManager(self.config, self.activity.assetManager);
            printConfig(self.config);
            self.event_config_changed = false;
        }

        if (self.event_resumed and self.event_window != null) {
            if (self.vr == null) enter_vr: {
                const vr = ovr.Mobile.enterVrMode(.{
                    .Flags = ovr.MODE_FLAG_FRONT_BUFFER_SRGB | ovr.MODE_FLAG_NATIVE_WINDOW,
                    .Java = self.java,
                    .Display = @ptrToInt(self.egl.display),
                    .WindowSurface = @ptrToInt(self.event_window),
                    .ShareContext = @ptrToInt(self.egl.context),
                }) catch {
                    app_log.err("Invalid ANativeWindow!", .{});
                    self.event_window = null;
                    break :enter_vr;
                };

                self.vr = vr;
                _ = vr.setClockLevels(self.cpu_level, self.gpu_level);
                _ = vr.setPerfThread(.main, self.main_thread_tid);
                _ = vr.setPerfThread(.renderer, self.renderer_thread_tid);
            }
        } else {
            if (self.vr) |vr| {
                vr.leaveVrMode();
                self.vr = null;
            }
        }
    }

    fn handleOvrEvents(self: *Self) void {
        _ = self;
        var buffer: ovr.EventDataBuffer = undefined;

        while (true) {
            const header = &buffer.EventHeader;
            const res = ovr.pollEvent(header);
            if (res != ovr.Success) break;

            switch (header.EventType) {
                .data_lost => {
                    const dl = header.cast(ovr.EventDataLost);
                    app_log.info("Ovr event: {}\n", .{dl.EventHeader.EventType});
                },
                .visibility_gained => {
                    const vg = header.cast(ovr.EventVisibilityGained);
                    app_log.info("Ovr event: {}\n", .{vg.EventHeader.EventType});
                },
                .visibility_lost => {
                    const vl = header.cast(ovr.EventVisibilityLost);
                    app_log.info("Ovr event: {}\n", .{vl.EventHeader.EventType});
                },
                .focus_gained => {
                    // FOCUS_GAINED is sent when the application is in the foreground and has
                    // input focus. This may be due to a system overlay relinquishing focus
                    // back to the application.
                    const fg = header.cast(ovr.EventFocusGained);
                    app_log.info("Ovr event: {}\n", .{fg.EventHeader.EventType});
                },
                .focus_lost => {
                    // FOCUS_LOST is sent when the application is no longer in the foreground and
                    // therefore does not have input focus. This may be due to a system overlay taking
                    // focus from the application. The application should take appropriate action when
                    // this occurs.
                    const fl = header.cast(ovr.EventFocusLost);
                    app_log.info("Ovr event: {}\n", .{fl.EventHeader.EventType});
                },
                .display_refresh_rate_change => {
                    const drrc = header.cast(ovr.EventDisplayRefreshRateChange);
                    app_log.info("Ovr event: {} from {} to {}\n", .{ drrc.EventHeader.EventType, drrc.fromDisplayRefreshRate, drrc.toDisplayRefreshRate });
                },
                else => {
                    app_log.info("Ovr event: unknown ({})\n", .{@enumToInt(header.EventType)});
                },
            }
        }
    }

    fn handleInput(self: *Self) void {
        const vr = self.vr orelse return;

        app_log.info("ZINPUT: Frame {}\n", .{self.frame_index});
        var header: ovr.InputCapabilityHeader = undefined;
        var index: u32 = 0;
        while (true) : (index += 1) {
            {
                const rc = vr.enumerateInputDevices(index, &header);
                if (rc < 0) break;
            }

            app_log.info("ZINPUT: [{}]: device {} is {}\n", .{ index, header.DeviceID, header.Type });

            inspect_item: {
                switch (header.Type) {
                    .tracked_remote => {
                        var state: ovr.InputStateTrackedRemote = undefined;
                        state.Header.ControllerType = .tracked_remote;
                        state.Header.TimeInSeconds = self.display_time;
                        const rc = vr.getCurrentInputState(header.DeviceID, &state.Header);
                        if (rc < 0) {
                            app_log.warn("ZINPUT:   Error {} from getCurrentInputState\n", .{rc});
                            break :inspect_item;
                        }

                        app_log.info("ZINPUT:   = {}\n", .{state});
                    },
                    .standard_pointer => {
                        var state: ovr.InputStateStandardPointer = undefined;
                        state.Header.ControllerType = .standard_pointer;
                        state.Header.TimeInSeconds = self.display_time;
                        const rc = vr.getCurrentInputState(header.DeviceID, &state.Header);
                        if (rc < 0) {
                            app_log.warn("ZINPUT:   Error {} from getCurrentInputState\n", .{rc});
                            break :inspect_item;
                        }

                        const pointer_base = ovr.Vector3f.init(0, 0, 0);
                        const pointer_x = ovr.Vector3f.init(0.1, 0, 0);
                        const pointer_y = ovr.Vector3f.init(0, 0.1, 0);
                        const pointer_z = ovr.Vector3f.init(0, 0, 0.1);
                        const pointer_point = ovr.Vector3f.init(0, 0, -0.3 - 0.3 * state.PointerStrength);

                        const transform = state.PointerPose.toMatrix();

                        const tf_base = transform.transform(pointer_base.projected()).position();
                        const tf_point = transform.transform(pointer_point.projected()).position();
                        const tf_x = transform.transform(pointer_x.projected()).position();
                        const tf_y = transform.transform(pointer_y.projected()).position();
                        const tf_z = transform.transform(pointer_z.projected()).position();

                        self.scene.drawDebugLine(tf_base, tf_point, colors.purple);
                        self.scene.drawDebugLine(tf_base, tf_x, colors.red);
                        self.scene.drawDebugLine(tf_base, tf_y, colors.green);
                        self.scene.drawDebugLine(tf_base, tf_z, colors.blue);

                        app_log.info("ZINPUT:   = {}\n", .{state});
                    },
                    .hand => {
                        // var state: ovr.InputStateHand = undefined;
                        // state.Header.ControllerType = .hand;
                        // const rc = vr.getCurrentInputState(header.DeviceID, &state.Header);

                        // var pose = ovr.HandPose{};
                        // vr.getHandPose(header.DeviceID,
                    },
                    else => {},
                }
            }
        }

        app_log.info("ZINPUT: \n", .{});
    }

    fn updateSimulation(self: *Self, time_since_start: f64) void {
        const rot = @floatCast(f32, time_since_start);
        self.rotation = .{
            .x = rot,
            .y = rot,
            .z = rot,
        };
    }

    fn renderFrame(self: *Self, tracking: ovr.Tracking2) ovr.LayerProjection2 {
        const scene = &self.scene;

        // map and update the instance transform buffer
        {
            var rotation_matrices: [Scene.num_rotations]ovr.Matrix4f = undefined;
            for (rotation_matrices) |*m, i| {
                m.* = ovr.Matrix4f.createRotation(
                    scene.rotations[i].x + self.rotation.x,
                    scene.rotations[i].y + self.rotation.y,
                    scene.rotations[i].z + self.rotation.z,
                );
            }

            GL(c.glBindBuffer(c.GL_ARRAY_BUFFER, scene.instance_transform_buffer), @src());
            const mapped = GL(c.glMapBufferRange(
                c.GL_ARRAY_BUFFER,
                0,
                Scene.num_instances * @sizeOf(ovr.Matrix4f),
                c.GL_MAP_WRITE_BIT | c.GL_MAP_INVALIDATE_BUFFER_BIT,
            ), @src());
            const instances = @ptrCast(*[Scene.num_instances]ovr.Matrix4f, @alignCast(@alignOf(ovr.Matrix4f), mapped));

            for (instances) |*tf, i| {
                tf.* = rotation_matrices[scene.cube_rotations[i]];
                const position = scene.cube_positions[i];
                tf.M[3] = .{ position.x, position.y, position.z, 1.0 };
            }

            _ = GL(c.glUnmapBuffer(c.GL_ARRAY_BUFFER), @src());
            GL(c.glBindBuffer(c.GL_ARRAY_BUFFER, 0), @src());
        }

        // update the scene matrices
        {
            GL(c.glBindBuffer(c.GL_UNIFORM_BUFFER, scene.scene_matrices), @src());
            const mapped = GL(c.glMapBufferRange(
                c.GL_UNIFORM_BUFFER,
                0,
                4 * @sizeOf(ovr.Matrix4f),
                c.GL_MAP_WRITE_BIT | c.GL_MAP_INVALIDATE_BUFFER_BIT,
            ), @src());
            const matrices = @ptrCast(*[4]ovr.Matrix4f, @alignCast(@alignOf(ovr.Matrix4f), mapped));

            matrices[0] = tracking.Eye[0].ViewMatrix.transpose();
            matrices[1] = tracking.Eye[1].ViewMatrix.transpose();
            matrices[2] = tracking.Eye[0].ProjectionMatrix.transpose();
            matrices[3] = tracking.Eye[1].ProjectionMatrix.transpose();

            _ = GL(c.glUnmapBuffer(c.GL_UNIFORM_BUFFER), @src());
            GL(c.glBindBuffer(c.GL_UNIFORM_BUFFER, 0), @src());
        }

        // update the debug line data
        {
            GL(c.glBindBuffer(c.GL_ARRAY_BUFFER, scene.debug_line_instance_buffer), @src());
            GL(c.glBufferData(
                c.GL_ARRAY_BUFFER,
                @intCast(c.GLsizei, scene.debug_lines.items.len * @sizeOf(DebugLine)),
                scene.debug_lines.items.ptr,
                c.GL_STREAM_DRAW,
            ), @src());
            GL(c.glBindBuffer(c.GL_ARRAY_BUFFER, 0), @src());
        }

        // set up a swapchain projection layer
        var layer: ovr.LayerProjection2 = .{
            .HeadPose = tracking.HeadPose,
        };
        for (layer.Textures) |*tex, i| {
            const fb_index: usize = if (self.num_buffers == 1) 0 else i;
            const framebuffer = &self.framebuffers[fb_index];
            tex.ColorSwapChain = framebuffer.color_texture_swapchain;
            tex.SwapChainIndex = @intCast(c_int, framebuffer.texture_swapchain_index);
            tex.TexCoordsFromTanAngles = tracking.Eye[i].ProjectionMatrix.tanAngleMatrixFromProjection();
        }
        layer.Header.Flags.chromatic_aberration_correction = true;

        // render the eye images
        for (self.framebuffers[0..self.num_buffers]) |*fb, i| {
            fb.setCurrent();

            GL(c.glUseProgram(scene.program.program), @src());
            GL(c.glBindBufferBase(
                c.GL_UNIFORM_BUFFER,
                @intCast(c_uint, scene.program.uniform_bindings[Uniform.scene_matrices]),
                scene.scene_matrices,
            ), @src());

            // NOTE: view_id will not be present when multiview path is enabled.
            if (scene.program.uniform_locations[Uniform.view_id] >= 0) {
                GL(c.glUniform1i(scene.program.uniform_locations[Uniform.view_id], @intCast(c_int, i)), @src());
            }

            GL(c.glEnable(c.GL_SCISSOR_TEST), @src());
            GL(c.glDepthMask(c.GL_TRUE), @src());
            GL(c.glEnable(c.GL_DEPTH_TEST), @src());
            GL(c.glDepthFunc(c.GL_LEQUAL), @src());
            GL(c.glEnable(c.GL_CULL_FACE), @src());
            GL(c.glCullFace(c.GL_BACK), @src());
            GL(c.glViewport(0, 0, fb.width, fb.height), @src());
            GL(c.glScissor(0, 0, fb.width, fb.height), @src());
            GL(c.glClearColor(0.2, 0.2, 0.2, 1.0), @src());
            GL(c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT), @src());

            GL(c.glBindVertexArray(scene.cube.vertex_array_object), @src());
            GL(c.glDrawElementsInstanced(
                c.GL_TRIANGLES,
                @intCast(c_int, scene.cube.index_count),
                c.GL_UNSIGNED_SHORT,
                null,
                Scene.num_instances,
            ), @src());

            GL(c.glDepthMask(c.GL_FALSE), @src());
            GL(c.glDisable(c.GL_DEPTH_TEST), @src());

            GL(c.glUseProgram(scene.debug_line_program.program), @src());
            GL(c.glBindBufferBase(
                c.GL_UNIFORM_BUFFER,
                @intCast(c_uint, scene.debug_line_program.uniform_bindings[Uniform.scene_matrices]),
                scene.scene_matrices,
            ), @src());

            GL(c.glBindVertexArray(scene.debug_line_vao), @src());
            GL(c.glDrawArraysInstanced(
                c.GL_LINES,
                0, // starting index
                2, // vertex count
                @intCast(c.GLint, scene.debug_lines.items.len), // instance count
            ), @src());

            scene.debug_lines.clearRetainingCapacity();

            GL(c.glBindVertexArray(0), @src());
            GL(c.glUseProgram(0), @src());

            fb.resolve();
            fb.advance();
        }

        Framebuffer.setNone();

        return layer;
    }

    fn mainLoop(self: *Self) !void {
        app_log.info("mainLoop() started\n", .{});

        // load app configuration
        self.config = android.AConfiguration_new() orelse return error.OutOfMemory;
        defer android.AConfiguration_delete(self.config);

        android.AConfiguration_fromAssetManager(self.config, self.activity.assetManager);
        printConfig(self.config);

        // set up Oculus<->Java interface object
        {
            const vm = self.activity.vm;
            var env: *android.JNIEnv = undefined;
            _ = vm.*.AttachCurrentThread(vm, &env, null);
            self.java = .{
                .Vm = vm,
                .Env = env,
                .ActivityObject = self.activity.clazz,
            };

            // AttachCurrentThread resets the thread name, set it after that call.
            _ = std.os.prctl(.SET_NAME, .{@ptrToInt("AndroidApp.mainLoop")}) catch undefined;
        }
        defer _ = self.java.Vm.*.DetachCurrentThread(self.java.Vm);

        {
            ovr.initialize(.{ .Java = self.java }) catch |err| {
                app_log.err("ERROR: vrapi_Initialize() returned {}\n", .{err});
                return err;
            };
        }

        // init EGL context
        self.egl = EGLContext.init(.gles3) catch |err| {
            app_log.err("Failed to initialize EGL for window: {}\n", .{err});
            return err;
        };
        defer self.egl.deinit();

        // check EGL extensions
        {
            var has_multiview = false;
            var has_texture_border_clamp = false;

            if (@ptrCast(?[*:0]const u8, c.glGetString(c.GL_EXTENSIONS))) |allExtensionsNullTerm| {
                const allExtensions = std.mem.sliceTo(allExtensionsNullTerm, 0);
                has_multiview =
                    std.mem.indexOf(u8, allExtensions, "GL_OVR_multiview2") != null and
                    std.mem.indexOf(u8, allExtensions, "GL_OVR_multiview_multisampled_render_to_texture") != null;
                has_texture_border_clamp =
                    std.mem.indexOf(u8, allExtensions, "GL_EXT_texture_border_clamp") != null or
                    std.mem.indexOf(u8, allExtensions, "GL_OES_texture_border_clamp") != null;
            }
            app_log.info("multiview: {}, texture border clamp: {}\n", .{ has_multiview, has_texture_border_clamp });

            self.use_multiview = has_multiview;
        }

        GL(c.glDisable(glext.GL_FRAMEBUFFER_SRGB_EXT), @src());

        self.main_thread_tid = @intCast(u32, std.Thread.getCurrentId());

        // init framebuffers
        {
            const width = self.java.getSystemPropertyInt(.suggested_eye_texture_width);
            const height = self.java.getSystemPropertyInt(.suggested_eye_texture_height);

            self.num_buffers = if (self.use_multiview) 1 else ovr.Eye.count;
            for (self.framebuffers[0..self.num_buffers]) |*fb| {
                fb.* = try Framebuffer.init(
                    self.use_multiview,
                    c.GL_SRGB8_ALPHA8,
                    width,
                    height,
                    num_multisamples,
                    c_allocator,
                );
            }
        }
        defer for (self.framebuffers[0..self.num_buffers]) |*fb| fb.deinit(c_allocator);

        const start_time = getTimeInSeconds();

        while (self.running.load(.SeqCst)) {
            // update thread state for android events from other threads
            self.handleAndroidEvents();

            // flush ovr events
            self.handleOvrEvents();

            // handle input
            self.handleInput();

            const vr = self.vr orelse {
                // give event threads time to run before taking the event mutex again
                std.time.sleep(std.time.ns_per_ms * 8);
                _ = if (true) continue else {}; // workaround for ZLS bug
            };

            if (!self.scene.isCreated()) {
                // show a loading screen
                var black_layer = ovr.LayerProjection2.default_black;
                black_layer.Header.Flags.inhibit_srgb_framebuffer = true;

                var icon_layer = ovr.LayerLoadingIcon2.default;
                icon_layer.Header.Flags.inhibit_srgb_framebuffer = true;

                const layers = [_]*ovr.LayerHeader2{
                    &black_layer.Header,
                    &icon_layer.Header,
                };

                _ = vr.submitFrame2(.{
                    .Flags = .{ .flush = true },
                    .SwapInterval = 1,
                    .FrameIndex = self.frame_index,
                    .DisplayTime = self.display_time,
                    .LayerCount = layers.len,
                    .Layers = &layers,
                });

                // do the creation
                try self.scene.create(self.use_multiview);
            }

            // This is the only place the frame index is incremented, right before
            // calling vrapi_GetPredictedDisplayTime().
            self.frame_index +%= 1;

            // Get the HMD pose, predicted for the middle of the time period during which
            // the new eye images will be displayed. The number of frames predicted ahead
            // depends on the pipeline depth of the engine and the synthesis rate.
            // The better the prediction, the less black will be pulled in at the edges.
            const predicted_display_time = vr.getPredictedDisplayTime(self.frame_index);
            const tracking = vr.getPredictedTracking2(predicted_display_time);

            self.display_time = predicted_display_time;

            self.updateSimulation(predicted_display_time - start_time);

            const world_layer = self.renderFrame(tracking);
            const layers = [_]*const ovr.LayerHeader2{&world_layer.Header};
            _ = vr.submitFrame2(.{
                .Flags = .{},
                .SwapInterval = self.swap_interval,
                .FrameIndex = self.frame_index,
                .DisplayTime = self.display_time,
                .LayerCount = layers.len,
                .Layers = &layers,
            });
        }

        app_log.info("mainLoop() finished\n", .{});
    }
};

inline fn GL(value: anytype, src: std.builtin.SourceLocation) @TypeOf(value) {
    if (check_gl_errors) {
        checkGlErrors(src);
    }
    return value;
}

fn checkGlErrors(src: std.builtin.SourceLocation) void {
    var count: u32 = 0;
    while (count < 10) : (count += 1) {
        const err = c.glGetError();
        if (err == c.GL_NO_ERROR) return;
        app_log.warn("{s}:{}:{}: GL error: {s} ({}) in {s}()\n", .{ src.file, src.line, src.column, glErrorString(err), err, src.fn_name });
    }
}

fn glErrorString(err: c.GLenum) []const u8 {
    return switch (err) {
        c.GL_NO_ERROR => "GL_NO_ERROR",
        c.GL_INVALID_ENUM => "GL_INVALID_ENUM",
        c.GL_INVALID_VALUE => "GL_INVALID_VALUE",
        c.GL_INVALID_OPERATION => "GL_INVALID_OPERATION",
        c.GL_INVALID_FRAMEBUFFER_OPERATION => "GL_INVALID_FRAMEBUFFER_OPERATION",
        c.GL_OUT_OF_MEMORY => "GL_OUT_OF_MEMORY",
        else => "Unknown",
    };
}

fn glFramebufferStatusString(err: c.GLenum) []const u8 {
    return switch (err) {
        c.GL_FRAMEBUFFER_UNDEFINED => "GL_FRAMEBUFFER_UNDEFINED",
        c.GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT => "GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT",
        c.GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT => "GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT",
        c.GL_FRAMEBUFFER_UNSUPPORTED => "GL_FRAMEBUFFER_UNSUPPORTED",
        c.GL_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE => "GL_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE",
        else => "Unknown framebuffer status",
    };
}
