const std = @import("std");

/// This is equivalent to the constants in std.os.linux.CLOCK, but only
/// CLOCK_MONOTONIC and CLOCK_BOOTTIME are allowed.
pub const Clock = enum(i32) {
    monotonic = 1,
    boottime = 7,
    _,
};
pub const Direction = enum(i32) {
    output = 0,
    input = 1,
    _,
};
pub const Format = enum(i32) {
    invalid = -1,
    unspecified = 0,
    pcm_i16 = 1,
    pcm_float = 2,
    _,
};
pub const Result = enum(i32) {
    ok = 0,
    error_disconnected = -899,
    error_illegal_argument = -898,
    error_invalid_state = -895,
    error_invalid_handle = -892,
    error_unimplemented = -890,
    error_unavailable = -889,
    error_no_free_handles = -888,
    error_no_memory = -887,
    error_null = -886,
    error_timeout = -885,
    error_would_block = -884,
    error_invalid_format = -883,
    error_out_of_range = -882,
    error_no_service = -881,
    error_invalid_rate = -880,
    _,

    pub const convertToText = raw.AAudio_convertResultToText;

    pub fn toError(self: Result) Error {
        @setCold(true);
        switch (self) {
            .error_illegal_argument,
            .error_invalid_handle,
            .error_null,
            .error_out_of_range,
            => {
                if (std.debug.runtime_safety) {
                    std.debug.panic("Programmer error: {s}", .{@tagName(self)});
                }
                return Error.AAudio_Unknown;
            },

            .error_invalid_format => return Error.AAudio_InvalidFormat,
            .error_invalid_rate => return Error.AAudio_InvalidRate,
            .error_invalid_state => return Error.AAudio_InvalidState,
            .error_disconnected => return Error.AAudio_Disconnected,
            .error_unimplemented => return Error.AAudio_Unimplemented,
            .error_unavailable => return Error.AAudio_Unavailable,
            .error_no_free_handles => return Error.AAudio_OutOfHandles,
            .error_no_memory => return Error.AAudio_OutOfMemory,
            .error_timeout => return Error.AAudio_Timeout,
            .error_would_block => return Error.AAudio_WouldBlock,
            .error_no_service => return Error.AAudio_NoService,

            // This branch is hit when a create function returns no error
            // but results in a null value.
            .ok => return error.AAudio_Unknown,
            _ => return Error.AAudio_Unknown,
        }
    }
};

pub const Error = error{
    /// An unexpected or undocumented error is returned.
    /// This error is also returned for errors which indicate
    /// a programming mistake, such as invalid parameters.
    /// In safe modes, the program will panic instead for
    /// programming mistake errors.
    AAudio_Unknown,

    /// The audio device was disconnected. This could occur, for example, when headphones
    /// are plugged in or unplugged. The stream cannot be used after the device is disconnected.
    /// Applications should stop and close the stream.
    /// If this error is received in an error callback then another thread should be
    /// used to stop and close the stream.
    AAudio_Disconnected,

    /// The requested operation is not appropriate for the current state of AAudio.
    AAudio_InvalidState,

    /// A resource or information is unavailable.
    /// This could occur when an application tries to open too many streams,
    /// or a timestamp is not available.
    AAudio_Unavailable,

    /// No more handles are available
    AAudio_OutOfHandles,

    /// Memory allocation failed
    AAudio_OutOfMemory,

    /// An operation took longer than expected
    AAudio_Timeout,

    /// The operation did not succeed because it could not be performed immediately.
    /// A blocking implementation would wait for it to be ready.
    AAudio_WouldBlock,

    /// The requested data format is not supported by this implementation.
    AAudio_InvalidFormat,

    /// The AAudio service was not available.
    AAudio_NoService,

    /// The requested sample rate is not supported by this implementation.
    AAudio_InvalidRate,
};

pub const StreamState = enum(i32) {
    uninitialized = 0,
    unknown = 1,
    open = 2,
    starting = 3,
    started = 4,
    pausing = 5,
    paused = 6,
    flushing = 7,
    flushed = 8,
    stopping = 9,
    stopped = 10,
    closing = 11,
    closed = 12,
    disconnected = 13,
    _,

    pub const convertToText = raw.AAudio_convertStreamStateToText;
};
pub const SharingMode = enum(i32) {
    exclusive = 0,
    shared = 1,
    _,
};
pub const PerformanceMode = enum(i32) {
    none = 10,
    power_saving = 11,
    low_latency = 12,
    _,
};
pub const Usage = enum(i32) {
    media = 1,
    voice_communication = 2,
    voice_communication_signalling = 3,
    alarm = 4,
    notification = 5,
    notification_ringtone = 6,
    notification_event = 10,
    assistance_accessibility = 11,
    assistance_navigation_guidance = 12,
    assistance_sonification = 13,
    game = 14,
    assistant = 16,
    _,
};
pub const ContentType = enum(i32) {
    speech = 1,
    music = 2,
    movie = 3,
    sonification = 4,
    _,
};
pub const InputPreset = enum(i32) {
    generic = 1,
    camcorder = 5,
    voice_recognition = 6,
    voice_communication = 7,
    unprocessed = 9,
    voice_performance = 10,
    _,
};
pub const SessionId = enum(i32) {
    none = -1,
    allocate = 0,
    _,
};
pub const StreamBuilder = opaque {
    pub fn create() !*StreamBuilder {
        var self: ?*StreamBuilder = null;
        const rc = raw.AAudio_createStreamBuilder(&self);
        if (rc == Result.ok and self != null) return self.?;
        return error.AAudio_CreateStreamBuilderFailed;
    }

    pub const destroy = raw.AAudioStreamBuilder_delete;

    pub fn openStream(self: *StreamBuilder) Error!*Stream {
        var stream: ?*Stream = null;
        const rc = raw.AAudioStreamBuilder_openStream(self, &stream);
        if (rc == .ok and stream != null) return stream.?;
        return rc.toError();
    }

    pub const setDeviceId = raw.AAudioStreamBuilder_setDeviceId;
    pub const setSampleRate = raw.AAudioStreamBuilder_setSampleRate;
    pub const setChannelCount = raw.AAudioStreamBuilder_setChannelCount;
    pub const setSamplesPerFrame = raw.AAudioStreamBuilder_setSamplesPerFrame;
    pub const setFormat = raw.AAudioStreamBuilder_setFormat;
    pub const setSharingMode = raw.AAudioStreamBuilder_setSharingMode;
    pub const setDirection = raw.AAudioStreamBuilder_setDirection;
    pub const setBufferCapacityInFrames = raw.AAudioStreamBuilder_setBufferCapacityInFrames;
    pub const setPerformanceMode = raw.AAudioStreamBuilder_setPerformanceMode;
    pub const setUsage = raw.AAudioStreamBuilder_setUsage;
    pub const setContentType = raw.AAudioStreamBuilder_setContentType;
    pub const setInputPreset = raw.AAudioStreamBuilder_setInputPreset;
    pub const setAllowedCapturePolicy = raw.AAudioStreamBuilder_setAllowedCapturePolicy;
    pub const setSessionId = raw.AAudioStreamBuilder_setSessionId;
    pub const setDataCallback = raw.AAudioStreamBuilder_setDataCallback;
    pub const setFramesPerDataCallback = raw.AAudioStreamBuilder_setFramesPerDataCallback;
    pub const setErrorCallback = raw.AAudioStreamBuilder_setErrorCallback;
};

pub const Stream = opaque {
    const DataCallbackResult = enum(i32) {
        @"continue" = 0,
        stop = 1,
    };
    pub const DataCallback = ?fn (?*Stream, ?*anyopaque, ?*anyopaque, i32) callconv(.C) DataCallbackResult;
    pub const ErrorCallback = ?fn (?*Stream, ?*anyopaque, Result) callconv(.C) void;

    pub const open = StreamBuilder.openStream;
    pub const close = raw.AAudioStream_close;

    pub fn requestStart(stream: *Stream) Error!void {
        const rc = raw.AAudioStream_requestStart(stream);
        if (rc == .ok) return;
        return rc.toError();
    }
    pub fn requestPause(stream: *Stream) Error!void {
        const rc = raw.AAudioStream_requestPause(stream);
        if (rc == .ok) return;
        return rc.toError();
    }
    pub fn requestFlush(stream: *Stream) Error!void {
        const rc = raw.AAudioStream_requestFlush(stream);
        if (rc == .ok) return;
        return rc.toError();
    }
    pub fn requestStop(stream: *Stream) Error!void {
        const rc = raw.AAudioStream_requestStop(stream);
        if (rc == .ok) return;
        return rc.toError();
    }
    pub const getState = raw.AAudioStream_getState;

    pub fn waitForStateChange(stream: *Stream, currentState: StreamState, timeoutNanoseconds: i64) Error!StreamState {
        var state: StreamState = .uninitialized;
        const rc = raw.AAudioStream_waitForStateChange(stream, currentState, &state, timeoutNanoseconds);
        if (rc == .ok) return state;
        return rc.toError();
    }
    pub fn read(stream: *Stream, buffer: *anyopaque, num_frames: u32, timeout_nanoseconds: i64) Error!u32 {
        const rc = raw.AAudioStream_read(stream, buffer, @intCast(i32, num_frames), timeout_nanoseconds);
        if (rc >= 0) return @intCast(u32, rc);
        return @intToEnum(Result, rc).toError();
    }
    pub fn write(stream: *Stream, buffer: *const anyopaque, num_frames: u32, timeout_nanoseconds: i64) Error!u32 {
        const rc = raw.AAudioStream_write(stream, buffer, @intCast(i32, num_frames), timeout_nanoseconds);
        if (rc >= 0) return @intCast(u32, rc);
        return @intToEnum(Result, rc).toError();
    }
    pub fn setBufferSizeInFrames(stream: *Stream, num_frames: u32) Error!u32 {
        const rc = raw.AAudioStream_setBufferSizeInFrames(stream, num_frames);
        if (rc >= 0) return @intCast(u32, rc);
        return @intToEnum(Result, rc).toError();
    }

    pub const Timestamp = struct {
        frame_position: i64,
        time_nanoseconds: i64,
    };
    pub fn getTimestamp(stream: *Stream, clock_id: Clock) Timestamp {
        var result: Timestamp = undefined;
        const rc = raw.AAudioStream_getTimestamp(stream, clock_id, &result.frame_position, &result.time_nanoseconds);
        if (rc == .ok) return result;
        return rc.toError();
    }

    pub const getBufferSizeInFrames = raw.AAudioStream_getBufferSizeInFrames;
    pub const getFramesPerBurst = raw.AAudioStream_getFramesPerBurst;
    pub const getBufferCapacityInFrames = raw.AAudioStream_getBufferCapacityInFrames;
    pub const getFramesPerDataCallback = raw.AAudioStream_getFramesPerDataCallback;
    pub const getXRunCount = raw.AAudioStream_getXRunCount;
    pub const getSampleRate = raw.AAudioStream_getSampleRate;
    pub const getChannelCount = raw.AAudioStream_getChannelCount;
    pub const getSamplesPerFrame = raw.AAudioStream_getSamplesPerFrame;
    pub const getDeviceId = raw.AAudioStream_getDeviceId;
    pub const getFormat = raw.AAudioStream_getFormat;
    pub const getSharingMode = raw.AAudioStream_getSharingMode;
    pub const getPerformanceMode = raw.AAudioStream_getPerformanceMode;
    pub const getDirection = raw.AAudioStream_getDirection;
    pub const getFramesWritten = raw.AAudioStream_getFramesWritten;
    pub const getFramesRead = raw.AAudioStream_getFramesRead;
    pub const getSessionId = raw.AAudioStream_getSessionId;
    pub const getUsage = raw.AAudioStream_getUsage;
    pub const getContentType = raw.AAudioStream_getContentType;
    pub const getInputPreset = raw.AAudioStream_getInputPreset;
};

pub const raw = struct {
    pub extern fn AAudio_convertResultToText(returnCode: Result) ?[*:0]const u8;
    pub extern fn AAudio_convertStreamStateToText(state: StreamState) ?[*:0]const u8;
    pub extern fn AAudio_createStreamBuilder(builder: *?*StreamBuilder) Result;
    pub extern fn AAudioStreamBuilder_setDeviceId(builder: *StreamBuilder, deviceId: i32) void;
    pub extern fn AAudioStreamBuilder_setSampleRate(builder: *StreamBuilder, sampleRate: i32) void;
    pub extern fn AAudioStreamBuilder_setChannelCount(builder: *StreamBuilder, channelCount: i32) void;
    pub extern fn AAudioStreamBuilder_setSamplesPerFrame(builder: *StreamBuilder, samplesPerFrame: i32) void;
    pub extern fn AAudioStreamBuilder_setFormat(builder: *StreamBuilder, format: Format) void;
    pub extern fn AAudioStreamBuilder_setSharingMode(builder: *StreamBuilder, sharingMode: SharingMode) void;
    pub extern fn AAudioStreamBuilder_setDirection(builder: *StreamBuilder, direction: Direction) void;
    pub extern fn AAudioStreamBuilder_setBufferCapacityInFrames(builder: *StreamBuilder, numFrames: i32) void;
    pub extern fn AAudioStreamBuilder_setPerformanceMode(builder: *StreamBuilder, mode: PerformanceMode) void;
    pub extern fn AAudioStreamBuilder_setUsage(builder: *StreamBuilder, usage: Usage) void;
    pub extern fn AAudioStreamBuilder_setContentType(builder: *StreamBuilder, contentType: ContentType) void;
    pub extern fn AAudioStreamBuilder_setInputPreset(builder: *StreamBuilder, inputPreset: InputPreset) void;
    pub extern fn AAudioStreamBuilder_setSessionId(builder: *StreamBuilder, sessionId: SessionId) void;
    pub extern fn AAudioStreamBuilder_setDataCallback(builder: *StreamBuilder, callback: ?Stream.DataCallback, userData: ?*anyopaque) void;
    pub extern fn AAudioStreamBuilder_setFramesPerDataCallback(builder: *StreamBuilder, numFrames: i32) void;
    pub extern fn AAudioStreamBuilder_setErrorCallback(builder: *StreamBuilder, callback: ?Stream.ErrorCallback, userData: ?*anyopaque) void;
    pub extern fn AAudioStreamBuilder_openStream(builder: *StreamBuilder, stream: *?*Stream) Result;
    pub extern fn AAudioStreamBuilder_delete(builder: *StreamBuilder) Result;
    pub extern fn AAudioStream_close(stream: *Stream) Result;
    pub extern fn AAudioStream_requestStart(stream: *Stream) Result;
    pub extern fn AAudioStream_requestPause(stream: *Stream) Result;
    pub extern fn AAudioStream_requestFlush(stream: *Stream) Result;
    pub extern fn AAudioStream_requestStop(stream: *Stream) Result;
    pub extern fn AAudioStream_getState(stream: *Stream) StreamState;
    pub extern fn AAudioStream_waitForStateChange(stream: *Stream, inputState: StreamState, nextState: *StreamState, timeoutNanoseconds: i64) Result;
    pub extern fn AAudioStream_read(stream: *Stream, buffer: ?*anyopaque, numFrames: i32, timeoutNanoseconds: i64) i32;
    pub extern fn AAudioStream_write(stream: *Stream, buffer: ?*const anyopaque, numFrames: i32, timeoutNanoseconds: i64) i32;
    pub extern fn AAudioStream_setBufferSizeInFrames(stream: *Stream, numFrames: i32) i32;
    pub extern fn AAudioStream_getBufferSizeInFrames(stream: *Stream) i32;
    pub extern fn AAudioStream_getFramesPerBurst(stream: *Stream) i32;
    pub extern fn AAudioStream_getBufferCapacityInFrames(stream: *Stream) i32;
    pub extern fn AAudioStream_getFramesPerDataCallback(stream: *Stream) i32;
    pub extern fn AAudioStream_getXRunCount(stream: *Stream) i32;
    pub extern fn AAudioStream_getSampleRate(stream: *Stream) i32;
    pub extern fn AAudioStream_getChannelCount(stream: *Stream) i32;
    pub extern fn AAudioStream_getSamplesPerFrame(stream: *Stream) i32;
    pub extern fn AAudioStream_getDeviceId(stream: *Stream) i32;
    pub extern fn AAudioStream_getFormat(stream: *Stream) Format;
    pub extern fn AAudioStream_getSharingMode(stream: *Stream) SharingMode;
    pub extern fn AAudioStream_getPerformanceMode(stream: *Stream) PerformanceMode;
    pub extern fn AAudioStream_getDirection(stream: *Stream) Direction;
    pub extern fn AAudioStream_getFramesWritten(stream: *Stream) i64;
    pub extern fn AAudioStream_getFramesRead(stream: *Stream) i64;
    pub extern fn AAudioStream_getSessionId(stream: *Stream) SessionId;
    pub extern fn AAudioStream_getTimestamp(stream: *Stream, clockid: Clock, framePosition: *i64, timeNanoseconds: *i64) Result;
    pub extern fn AAudioStream_getUsage(stream: *Stream) Usage;
    pub extern fn AAudioStream_getContentType(stream: *Stream) ContentType;
    pub extern fn AAudioStream_getInputPreset(stream: *Stream) InputPreset;
};
