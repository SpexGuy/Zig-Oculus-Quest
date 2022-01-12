//! Copyright © Facebook Technologies, LLC and its affiliates. All rights reserved.
//! Your use of this SDK or tool is subject to the Oculus SDK License Agreement, available at https://developer.oculus.com/licenses/oculussdk/
//!
//! 
//! \section intro_sec Introduction
//! 
//! The OVRAudio API is a C/C++ interface that implements HRTF-based spatialization
//! and optional room effects. Your application can directly use this API, though
//! most developers will access it indirectly via one of our plugins for popular
//! middleware such as FMOD, Wwise, and Unity.  Starting with Unreal Engine 4.8 it
//! will also be available natively.
//! 
//! OVRAudio is a low-level API, and as such, it does not buffer or manage sound
//! state for applications. It positions sounds by filtering incoming monophonic
//! audio buffers and generating floating point stereo output buffers. Your
//! application must then mix, convert, and feed this signal to the appropriate
//! audio output device.
//! 
//! OVRAudio does not handle audio subsystem configuration and output. It is up to
//! developers to implement this using either a low-level system interface
//! (e.g., DirectSound, WASAPI, CoreAudio, ALSA) or a high-level middleware
//! package (e.g,  FMOD, Wwise, Unity).
//! 
//! If you are unfamiliar with the concepts behind audio and virtual reality, we
//! strongly recommend beginning with the companion guide
//! *Introduction to Virtual Reality Audio*.
//! 
//! \section sysreq System Requirements
//! 
//! -Windows 7 and 8.x (32 and 64-bit)
//! -Android
//! -Mac OS X 10.9+
//! 
//! \section installation Installation
//! 
//! OVRAudio is distributed as a compressed archive. To install, unarchive it in
//! your development tree and update your compiler include and lib paths
//! appropriately.
//! 
//! When deploying an application on systems that support shared libraries, you
//! must ensure that the appropriate DLL/shared library is in the same directory
//! as your application (Android uses static libraries).
//! 
//! \section multithreading Multithreading
//! 
//! OVRAudio does not create multiple threads  and uses a per-context mutex for
//! safe read/write access via the API functions from different threads.  It is the
//! application's responsibility to coordinate context management between different
//! threads.
//! 
//! \section using Using OVRAudio
//! 
//! This section covers the basics of using OVRAudio in your game or application.
//! 
//! \subsection Initialization
//! 
//! The following code sample illustrates how to initialize OVRAudio.
//! 
//! Contexts contain the state for a specific spatializer instance.  In most cases
//! you will only need a single context.
//! 
//! \code{.zig}
//! const std = @import("std");
//! const android = @import("android");
//! const audio = android.ovr.audio;
//! 
//! var ctx: audio.Context = undefined;
//! 
//! fn setup() !void {
//!     // Version checking is not strictly necessary but it's a good idea!
//!     const ver = audio.getVersion();
//!     std.debug.print("Using OVRAudio: {s}\n", .{});
//! 
//!     if ( ver.major != audio.major_version ||
//!          ver.minor != audio.minor_version ) {
//!       std.debug.print(
//!         "Mismatched Audio SDK version! Built against {}.{}.{}\n",
//!         .{ audio.major_version, audio.minor_version, audio.patch_version },
//!       );
//!     }
//!
//!     try ctx.create(.{
//!       .sample_rate = 48000,
//!       .buffer_length = 512,
//!       .max_num_sources = 16,
//!     });
//! }
//! 
//! \endcode
//! 
//! \subsection gflags Global Flags
//! 
//! A few global flags control OVRAudio's implementation.  These are managed with
//! Context.enable(..) and the appropriate flag:
//! - .simple_room_modeling: Enables box room modeling of
//! reverberations and reflections
//! - .late_reverberation: (Requires .simple_room_modeling)
//! Splits room modeling into two components: early reflections (echoes) and late
//! reverberations.  Late reverberation may be independently disabled.
//! - .randomize_reverb: (requires .simple_room_modeling
//! and .late_reverberation) Randomizes reverberation tiles, creating
//! a more natural sound.
//! 
//! \subsection sourcemanagement Audio Source Management
//! 
//! OVRAudio maintains a set of N audio sources, where N is determined by the value
//! specified in ContextConfiguration.max_num_sources passed to
//! Context.create(..).
//! 
//! Each source is associated with a set of parameter, such as:
//! - position (Context.setAudioSourcePosition)
//! - attenuation range (Context.setAudioSourceRange)
//! - flags (Context.setAudioSourceFlags)
//! - attenuation mode (Context.setAudioSourceAttenuationMode)
//! 
//! These may be changed at any time prior to a call to the spatialization APIs.  The
//! source index (0..N-1) is a parameter to the above functions.
//! 
//! Note: Supplying position values (such as nan, inf) will return an ovrError,
//! while denormals will be flushed to zero.
//! 
//! Note: Some lingering states such as late reverberation tails may carry over between
//! calls to the spatializer.  If you dynamically change source sounds bound to an audio
//! source (for example, you have a pool of OVRAudio sources), you will need to call
//! ovrAudio_ResetAudioSource to avoid any artifacts.
//! 
//! \subsection attenuation Attenuation
//! 
//! The volume of a sound is attenuated over distance, and this can be modeled in
//! different ways.  By default, OVRAudio does not perform any attenuation, as the most
//! common use case is an application or middleware defined attenuation curve.
//! 
//! If you want OVRAudio to attenuate volume based on distance between the sound
//! source and listener, call Context.setAudioSourceAttenuationMode with the
//! the appropriate mode.  OVRAudio can also scale volume by a fixed value using
//! SourceAttenuationMode.fixed.  If, for example, you have computed the
//! attenuation factor and would like OVRAudio to apply it during spatialization.
//! 
//! \subsection sourceflags Audio Source Flags
//! 
//! You may define properties of specific audio sources by setting appropriate flags
//! using the Context.setAudioSourceFlags API.  These flags include:
//! - SourceFlag.wide_band_hint: Set this to help mask certain artifacts for
//! wideband audio sources with a lot of spectral content, such as music, voice and
//! noise.
//! - SourceFlag.narrow_band_hint: Set this for narrowband audio sources that
//! lack broad spectral content such as pure tones (sine waves, whistles).
//! - SourceFlag.direct_time_of_arrival: Simulate travel time for a sound.  This
//! is physicaly correct, but may be perceived as less realistic, as games and media
//! commonly represent sound travel as instantaneous.
//! 
//! \subsection sourcesize Audio Source Size
//! 
//! OVRAudio treats sound sources as infinitely small point sources by default.
//! This works in most cases, but when a source approaches the listener it may sound
//! incorret, as if the sound were coming from between the listener's ears.  You may
//! set a virtual diameter for a sound source using Context.setAudioSourcePropertyf
//! with the flag SourceProperty.diameter.  As the listener enters the
//! sphere, the sounds seems to come from a wider area surrounding the listener's
//! head.
//! 
//! \subsection envparm Set Environmental Parameters
//! 
//! As the listener transitions into different environments, you can reconfigure the
//! environment effects parameters.  You may begin by simply inheriting the default
//! values or setting the values globally a single time.
//! 
//! NOTE: Reflections/reverberation must be enabled
//! 
//! \code{.zig}
//! fn enterRoom( float w, float h, float d, float r ) void {
//!      ovrAudioBoxRoomParameters brp = {};
//! 
//!      brp.brp_Size = sizeof( brp );
//!      brp.brp_ReflectLeft = brp.brp_ReflectRight =
//!      brp.brp_ReflectUp = brp.brp_ReflectDown =
//!      brp.brp_ReflectFront = brp.brp_ReflectBehind = r;
//! 
//!      brp.brp_Width = w;
//!      brp.brp_Height = h;
//!      brp.brp_Depth = d;
//! 
//!      ctx.setSimpleBoxRoomParameters(.{
//!          .reflect_left = r,
//!          .reflect_right = r,
//!          .reflect_up = r,
//!          .reflect_down = r,
//!          .reflect_behind = r,
//!          .reflect_front = r,
//!          .width = w,
//!          .height = h,
//!          .depth = d,
//!      }) catch |err| {
//!          std.debug.print("Failed to set room parameters: {}\n", .{err});
//!      };
//! }
//! \endcode
//! 
//! \subsection headtracking Head Tracking (Optional)
//! 
//! You may specify the listener's pose state using values retrieved directly from
//! the HMD using LibOVR:
//! \code{.zig}
//! fn setListenerPose( pose_state: ovr.PoseStateF ) void {
//!    ctx.setListenerPoseStatef( pose_state ) catch |err| {
//!        std.debug.print("Failed to set listener pose: {}\n", .{err});
//!    };
//! }
//! \endcode
//! 
//! All sound sources are transformed with reference to the specified pose so that
//! they remain positioned correctly relative to the listener. If you do not call
//! this function, the listener is assumed to be at (0,0,0) and looking forward
//! (down the -Z axis), and that all sounds are in listener-relative coordinates.
//! 
//! \subsection spatialization Applying 3D Spatialization
//! 
//! Applying 3D spatialiazation consists of looping over all of your sounds,
//! copying their data into intermediate buffers, and passing them to the
//! positional audio engine. It will in turn process the sounds with the
//! appropriate HRTFs and effects and return a floating point stereo buffer:
//! \code
//! fn processSounds( Sound *sounds, int NumSounds, float *MixBuffer ) void {
//!    // This assumes that all sounds want to be spatialized!
//!    // NOTE: In practice these should be 16-byte aligned, but for brevity
//!    // we're just showing them declared like this
//!    var flags: u32 = 0;
//!    var status: u32 = 0;
//! 
//!    var outbuffer: [ INPUT_BUFFER_SIZE * 2 ]f32 = undefined;
//!    var inbuffer: [ INPUT_BUFFER_SIZE ]f32 = undefined;
//! 
//!    var i: usize = 0;
//!    while ( i < num_sounds ) : ( i += 1 ) {
//!       // Set the sound's position in space (using OVR coordinates)
//!       // NOTE: if a pose state has been specified by a previous call to
//!       // Context.listenerPoseStateF then it will be transformed
//!       // by that as well
//!       ctx.setAudioSourcePos( i,
//!          sounds[ i ].X, sounds[ i ].Y, sounds[ i ].Z );
//! 
//!       // This sets the attenuation range from max volume to silent
//!       // NOTE: attenuation can be disabled or enabled
//!       ctx.setAudioSourceRange( i,
//!          sounds[ i ].RangeMin, sounds[ i ].RangeMax );
//! 
//!       // Grabs the next chunk of data from the sound, looping etc.
//!       // as necessary.  This is application specific code.
//!       sounds[ i ].GetSoundData( &inbuffer );
//! 
//!       // Spatialize the sound into the output buffer.  Note that there
//!       // are two APIs, one for interleaved sample data and another for
//!       // separate left/right sample data
//!       ctx.spatializeMonoSourceInterleaved( i,
//!           &status, &outbuffer, &inbuffer );
//! 
//!       // Do some mixing
//!       if (i == 0) {
//!           for (outbuffer) |v, j| MixBuffer[ j ] = v;
//!       } else {
//!           for (outbuffer) |v, j| MixBuffer[ j ] += v;
//!       }
//!    }
//! 
//!    // From here we'd send the MixBuffer on for more processing or
//!    // final device output
//! 
//!    playMixBuffer(MixBuffer);
//! }
//! \endcode
//! 
//! At that point we have spatialized sound mixed into our output buffer.
//! 
//! \subsection reverbtails Finishing Reverb Tails
//! 
//! If late reverberation and simple box room modeling are enabled then the there
//! will be more output for the reverberation tail after the input sound has finished.
//! To ensure that the reverberation tail is not cut off, you can continue to feed the
//! spatialization functions with silence (e.g. NULL source data) after all of the
//! input data has been processed to get the rest of the output. When the tail has
//! finished the OutStatus will contain SpatializationStatus.finished flag.
//! 
//! This correction should occur at the final output stage. In other words, it should be
//! applied directly on the stereo outputs and not on each sound.
//! 
//! \subsection shutdown Shutdown
//! 
//! When you are no longer using OVRAudio, shut it down by destroying any contexts.
//! 
//! \code
//! fn shutdownOvrAudio() void {
//!    ctx.destroy();]
//! }
//! \endcode
//!

const std = @import("std");
const builtin = @import("builtin");
const ovr = @import("ovr.zig");
const audio = @This();
const empty = struct{};

const assert = std.debug.assert;

// Like std.debug.assert, but does not assert unreachable
// in release modes.  This is for conditions which should
// always be true but should not invoke undefined behavior
// when violated.
inline fn safe_assert(condition: bool) void {
    if (std.debug.runtime_safety and !condition) {
        unreachable; // assert failed
    }
}

pub const has_geometry_api = builtin.target.os.tag == .windows;

/// Result type used by the OVRAudio API
pub const Result = c_int;

/// Success is zero, while all error types are non-zero values.
pub const Success = ovr.Success;

/// Enumerates error codes that can be returned by OVRAudio
pub const Error = struct {
    /// An unknown error has occurred.
    pub const AudioUnknown                                = 2000;
    /// An invalid parameter, e.g. NULL pointer or out of range variable, was passed
    pub const AudioInvalidParam                           = 2001;
    /// An unsupported sample rate was declared
    pub const AudioBadSampleRate                          = 2002;
    /// The DLL or shared library could not be found
    pub const AudioMissingDLL                             = 2003;
    /// Buffers did not meet 16b alignment requirements
    pub const AudioBadAlignment                           = 2004;
    /// audio function called before initialization
    pub const AudioUninitialized                          = 2005;
    /// HRTF provider initialization failed
    pub const AudioHRTFInitFailure                        = 2006;
    /// Mismatched versions between header and libs
    pub const AudioBadVersion                             = 2007;
    /// Couldn't find a symbol in the DLL
    pub const AudioSymbolNotFound                         = 2008;
    /// Late reverberation is disabled
    pub const SharedReverbDisabled                        = 2009;
    pub const AudioNoAvailableAmbisonicInstance           = 2017;
    pub const AudioMemoryAllocFailure                     = 2018;
    /// Unsupported feature
    pub const AudioUnsupportedFeature                     = 2019;
    /// Internal errors used by Audio SDK defined down towards public errors
    /// NOTE: Since we do not define a beginning range for Internal codes, make sure
    /// not to hard-code range checks (since that can vary based on build)
    pub const AudioInternalEnd                            = 2099;
};

pub const OvrAudioError = error {
    OvrAudio_Unknown,
    OvrAudio_BadSampleRate,
    OvrAudio_MissingDLL,
    OvrAudio_BadVersion,
    OvrAudio_SymbolNotFound,
    OvrAudio_SharedReverbDisabled,
    OvrAudio_NoAvailableAmbisonicInstance,
    OvrAudio_OutOfMemory,
    OvrAudio_UnsupportedFeature,
};

pub fn decodeError(err: Result) OvrAudioError {
    @setCold(true);

    switch (err) {
        Error.AudioBadSampleRate => return OvrAudioError.OvrAudio_BadSampleRate,
        Error.AudioMissingDLL => return OvrAudioError.OvrAudio_MissingDLL,
        Error.AudioBadVersion => return OvrAudioError.OvrAudio_BadVersion,
        Error.AudioSymbolNotFound => return OvrAudioError.OvrAudio_SymbolNotFound,
        Error.SharedReverbDisabled => return OvrAudioError.OvrAudio_SharedReverbDisabled,
        Error.AudioNoAvailableAmbisonicInstance => return OvrAudioError.OvrAudio_NoAvailableAmbisonicInstance,
        Error.AudioMemoryAllocFailure => return OvrAudioError.OvrAudio_OutOfMemory,
        Error.AudioUnsupportedFeature => return OvrAudioError.OvrAudio_UnsupportedFeature,

        Error.AudioHRTFInitFailure,
        Error.AudioUnknown,
        => return OvrAudioError.OvrAudio_Unknown,

        Error.AudioUninitialized,
        Error.AudioInvalidParam,
        Error.AudioBadAlignment,
        => {
            if (std.debug.runtime_safety) unreachable;
            return OvrAudioError.OvrAudio_Unknown;
        },

        else => return OvrAudioError.OvrAudio_Unknown,
    }
}

const Posef = ovr.Posef;

pub const MAJOR_VERSION = 1;
pub const MINOR_VERSION = 64;
pub const PATCH_VERSION = 0;

/// Audio source flags
///
/// \see Context.setAudioSourceFlags
pub const SourceFlags = packed struct {
    __align: u0 align(4) = 0,

    __pad0: u4 = 0,
    /// Wide band signal (music, voice, noise, etc.)
    wide_band_hint: bool = false,
    /// Narrow band signal (pure waveforms, e.g sine)
    narrow_band_hint: bool = false,
    /// Compensate for drop in bass from HRTF (deprecated)
    _deprecated_bass_compensation: bool = false,
    /// Time of arrival delay for the direct signal
    direct_time_of_arrival: bool = false,
    
    /// Disable reflections and reverb for a single AudioSource
    reflections_disabled: bool = false,
    /// Stereo AudioSource, INTERNAL USE ONLY
    _reserved_stereo: bool = false,
    __pad1: u5 = 0,
    /// Disable resampling IR to output rate, INTERNAL USE ONLY
    _reserved_disable_resampling: bool = false,

    __pad2: u16 = 0,
};

/// Audio source attenuation mode
///
/// \see Context.setAudioSourceAttenuationMode
pub const SourceAttenuationMode = enum (u32) {
    /// Sound is not attenuated, e.g. middleware handles attenuation
    none           = 0,
    /// Sound has fixed attenuation (passed to Context.setAudioSourceAttenuationMode)
    fixed          = 1,
    /// Sound uses internally calculated attenuation based on inverse square
    inverse_square = 2,

    _,
};

/// Global boolean flags
///
/// \see Context.enable
pub const Enable = enum (u32) {
    /// None
    none                     = 0,
    /// Enable/disable simple room modeling globally, default: disabled
    simple_room_modeling     = 2,
    /// Late reverbervation, requires simple room modeling enabled
    late_reverberation       = 3,
    /// Randomize reverbs to diminish artifacts.  Default: enabled.
    randomize_reverb         = 4,

    _,
};

/// Explicit override to select reflection and reverb system
///
/// \see Context.setReflectionModel
pub const ReflectionModel = enum (u32) {
    /// Room controlled by ovrAudioBoxRoomParameters
    static_shoe_box       = 0,
    /// Room automatically calculated by raycasting using OVRA_RAYCAST_CALLBACK
    dynamic_room_modeling = 1,
    /// Sound propgated using game geometry
    propagation_system    = 2,
    /// Automatically select highest quality (if geometry is set the propagation system
    /// will be active, otherwise if the callback is set dynamic room modeling is enabled,
    /// otherwise fallback to the static shoe box)
    automatic             = 3,

    _,
};

/// Internal use only
///
/// Internal use only
pub const _Reserved_HRTFInterpolationMethod = enum (u32) {
    _nearest,
    _simple_time_domain,
    _min_phase_time_domain,
    _phase_truncation,
    _phase_lerp,

    _,
};

/// Status mask returned by spatializer APIs
///
/// Mask returned from spatialization APIs consists of combination of these.
/// \see Context.spatializeMonoSourceLR
/// \see Context.spatializeMonoSourceInterleaved
pub const SpatializationStatus = packed struct {
    /// Buffer is empty and sound processing is finished
    finished: bool = false,
    /// Data still remains in buffer (e.g. reverberation tail)
    working: bool = false,
    __pad0: u30 = 0,
};

/// Performance counter enumerants
///
/// \see Context.getPerformanceCounter
/// \see Context.setPerformanceCounter
pub const PerformanceCounter = enum (u32) {
    /// Retrieve profiling information for spatialization
    spatialization             = 0,
    /// Retrieve profiling information for shared reverb
    shared_reverb              = 1,

    _,
};

/// Ambisonic formats
pub const AmbisonicFormat = enum (u32) {
    /// standard B-Format, channel order = WXYZ (W channel is -3dB)
    FuMa,
    /// ACN/SN3D standard, channel order = WYZX
    AmbiX,

    _,
};

/// Ambisonic spherical harmonic order
pub const AmbisonicOrder = enum (i32) {
    four_channel = 1,
    nine_channel = 2,
    _,

    pub fn channels(self: @This()) u32 {
        return ([_]u32{ 1, 4, 9 })[@intCast(u32, @enumToInt(self))];
    }
};

/// Ambisonic rendering modes
///
/// NOTE: Support for rendering ambisonics via virtual speaker layouts has been
/// discontinued in favor of improved decoding with spherical harmonics, which
/// uses no virtual speakers at all and provides better externalization.
///
pub const AmbisonicRenderMode = enum (i32) {
    /// (default) Uses a spherical harmonic representation of HRTF
    spherical_harmonics  = -1,
    /// Plays the W (omni) channel through left and right with no spatialization
    mono                 = -2,
};

/// Box room parameters used by ovrAudio_SetSimpleBoxRoomParameters
///
/// \see ovrAudio_SetSimpleBoxRoomParameters
pub const BoxRoomParameters = extern struct{
    /// Size of struct
    size: u32 = @sizeOf(@This()),
    /// Reflection values (0 - 0.97)
    reflect_left: f32,
    reflect_right: f32,
    reflect_up: f32,
    reflect_down: f32,
    reflect_behind: f32,
    reflect_front: f32,
    ///< Size of box in meters
    width: f32,
    height: f32,
    depth: f32,
};

pub const reverb_band_count = 4;
pub const reverb_sh_coef_count = 4;
pub const Bands = [reverb_band_count]f32;

pub const MaterialPreset = enum (u32) {
    AcousticTile,
    Brick,
    BrickPainted,
    Carpet,
    CarpetHeavy,
    CarpetHeavyPadded,
    CeramicTile,
    Concrete,
    ConcreteRough,
    ConcreteBlock,
    ConcreteBlockPainted,
    Curtain,
    Foliage,
    Glass,
    GlassHeavy,
    Grass,
    Gravel,
    GypsumBoard,
    PlasterOnBrick,
    PlasterOnConcreteBlock,
    Soil,
    SoundProof,
    Snow,
    Steel,
    Water,
    WoodThin,
    WoodThick,
    WoodFloor,
    WoodOnConcrete,

    // zig fmt: off
    const presets = std.enums.directEnumArray(@This(), Bands, 0, .{
        .AcousticTile =           Bands{ 0.488168418, 0.361475229, 0.339595377 , 0.498946249  },
        .Brick =                  Bands{ 0.975468814, 0.972064495, 0.949180186 , 0.930105388  },
        .BrickPainted =           Bands{ 0.975710571, 0.983324170, 0.978116691 , 0.970052719  },
        .Carpet =                 Bands{ 0.987633705, 0.905486643, 0.583110571 , 0.351053834  },
        .CarpetHeavy =            Bands{ 0.977633715, 0.859082878, 0.526479602 , 0.370790422  },
        .CarpetHeavyPadded =      Bands{ 0.910534739, 0.530433178, 0.294055820 , 0.270105422  },
        .CeramicTile =            Bands{ 0.990000010, 0.990000010, 0.982753932 , 0.980000019  },
        .Concrete =               Bands{ 0.990000010, 0.983324170, 0.980000019 , 0.980000019  },
        .ConcreteRough =          Bands{ 0.989408433, 0.964494646, 0.922127008 , 0.900105357  },
        .ConcreteBlock =          Bands{ 0.635267377, 0.652230680, 0.671053469 , 0.789051592  },
        .ConcreteBlockPainted =   Bands{ 0.902957916, 0.940235913, 0.917584062 , 0.919947326  },
        .Curtain =                Bands{ 0.686494231, 0.545859993, 0.310078561 , 0.399473131  },
        .Foliage =                Bands{ 0.518259346, 0.503568292, 0.578688800 , 0.690210819  },
        .Glass =                  Bands{ 0.655915797, 0.800631821, 0.918839693 , 0.923488140  },
        .GlassHeavy =             Bands{ 0.827098966, 0.950222731, 0.974604130 , 0.980000019  },
        .Grass =                  Bands{ 0.881126285, 0.507170796, 0.131893098 , 0.0103688836 },
        .Gravel =                 Bands{ 0.729294717, 0.373122454, 0.255317450 , 0.200263441  },
        .GypsumBoard =            Bands{ 0.721240044, 0.927690148, 0.934302270 , 0.910105407  },
        .PlasterOnBrick =         Bands{ 0.975696504, 0.979106009, 0.961063504 , 0.950052679  },
        .PlasterOnConcreteBlock = Bands{ 0.881774724, 0.924773932, 0.951497555 , 0.959947288  },
        .Soil =                   Bands{ 0.844084203, 0.634624243, 0.416662872 , 0.400000036  },
        .SoundProof =             Bands{ 0.000000000, 0.000000000, 0.000000000 , 0.000000000  },
        .Snow =                   Bands{ 0.532252669, 0.154535770, 0.0509644151, 0.0500000119 },
        .Steel =                  Bands{ 0.793111682, 0.840140402, 0.925591767 , 0.979736567  },
        .Water =                  Bands{ 0.970588267, 0.971753478, 0.978309572 , 0.970052719  },
        .WoodThin =               Bands{ 0.592423141, 0.858273327, 0.917242289 , 0.939999998  },
        .WoodThick =              Bands{ 0.812957883, 0.895329595, 0.941304684 , 0.949947298  },
        .WoodFloor =              Bands{ 0.852366328, 0.898992121, 0.934784114 , 0.930052698  },
        .WoodOnConcrete =         Bands{ 0.959999979, 0.941232264, 0.937923789 , 0.930052698  },
    });
    // zig fmt: on

    pub inline fn getReflectionBands(self: @This()) Bands {
        return presets[@enumToInt(self)];
    }
};

/// Box room parameters used by ovrAudio_SetAdvancedBoxRoomParameters
///
/// \see ovrAudio_SetAdvancedBoxRoomParameters
pub const AdvancedBoxRoomParameters = extern struct{
    ///< Size of struct
    size: u32 = @sizeOf(@This()),
    ///< Reflection bands (0 - 1.0)
    reflect_left: Bands,
    reflect_right: Bands,
    reflect_up: Bands,
    reflect_down: Bands,
    reflect_behind: Bands,
    reflect_front: Bands,
    ///< Size of box in meters
    width: f32,
    height: f32,
    depth: f32,
    ///< Whether box is centered on listener
    lock_to_listener_position: i32,
    room_position: ovr.Vector3f,
};

pub const RaycastCallback = fn (origin: ovr.Vector3f, direction: ovr.Vector3f, hit: *ovr.Vector3f, normal: *ovr.Vector3f, reflection_bands: *Bands, pctx: ?*anyopaque) callconv(.C) void;

pub const Version = struct {
    major: i32,
    minor: i32,
    patch: i32,
    string: [*:0]const u8,
};

/// Return library's built version information.
///
/// Can be called any time.
/// \param[out] Major pointer to integer that accepts major version number
/// \param[out] Minor pointer to integer that accepts minor version number
/// \param[out] Patch pointer to integer that accepts patch version number
///
/// \return Returns a string with human readable build information
///
pub fn getVersion() Version {
    var maj: i32 = 0;
    var min: i32 = 0;
    var pat: i32 = 0;
    const str = raw.ovrAudio_GetVersion(&maj, &min, &pat);
    return .{
        .major = maj,
        .minor = min,
        .patch = pat,
        .string = str orelse "(null)",
    };
}

/// Allocate properly aligned buffer to store samples.
///
/// Helper function that allocates 16-byte aligned sample data sufficient
/// for passing to the spatialization APIs.
///
/// \param NumSamples number of samples to allocate
/// \return Returns pointer to 16-byte aligned float buffer, or NULL on failure
/// \see ovrAudio_FreeSamples
///
pub inline fn allocSamples(num: usize) error{OvrAudio_OutOfMemory}![]f32 {
    const ptr = raw.ovrAudio_AllocSamples(@intCast(i32, num))
        orelse return error.OvrAudio_OutOfMemory;
    return ptr[0..num];
}

/// Free previously allocated buffer
///
/// Helper function that frees 16-byte aligned sample data previously
/// allocated by allocSamples.
///
/// \param Samples pointer to buffer previously allocated by allocSamples
/// \see allocSamples
///
pub inline fn freeSamples(buf: []f32) void {
    raw.ovrAudio_FreeSamples(buf.ptr);
}

pub const Transform = extern struct {
    /// Orientation vector x
    vx: [3]f32,
    /// Orientation vector y
    vy: [3]f32,
    /// Orientation vector z
    vz: [3]f32,
    /// Position
    pos: [3]f32,
};
/// Retrieve a transformation from an ovrPosef.
///
/// \param Pose[in] pose to fetch transform from
///
pub fn getTransformFromPose(pose: ovr.Posef) Transform {
    const m = pose.toMatrix();
    return .{
        .vx  = .{ m.M[0][0], m.M[1][0], m.M[2][0] },
        .vy  = .{ m.M[0][1], m.M[1][1], m.M[2][1] },
        .vz  = .{ m.M[0][2], m.M[1][2], m.M[2][2] },
        .pos = .{ m.M[0][3], m.M[1][3], m.M[2][3] },
    };
}

/// Quad-binaural spatialization
///
/// \param ForwardLR[in] pointer to stereo interleaved floating point binaural audio for the forward direction (0 degrees)
/// \param RightLR[in] pointer to stereo interleaved floating point binaural audio for the right direction (90 degrees)
/// \param BackLR[in] pointer to stereo interleaved floating point binaural audio for the backward direction (180 degrees)
/// \param LeftLR[in] pointer to stereo interleaved floating point binaural audio for the left direction (270 degrees)
/// \param LookDirectionX[in] X component of the listener direction vector
/// \param LookDirectionY[in] Y component of the listener direction vector
/// \param LookDirectionZ[in] Z component of the listener direction vector
/// \param NumSamples[in] size of audio buffers (in samples)
/// \param out_buffer[out] pointer to stereo interleaved floating point destination buffer
///
pub fn processQuadBinaural(
    forward_lr: [*]f32,
    right_lr: [*]f32,
    back_lr: [*]f32,
    left_lr: [*]f32,
    look_dir_x: f32,
    look_dir_y: f32,
    look_dir_z: f32,
    num_samples: usize,
    out_buffer: [*]f32,
) !void {
    const rc = raw.ovrAudio_ProcessQuadBinaural(forward_lr, right_lr, back_lr, left_lr, look_dir_x, look_dir_y, look_dir_z, @intCast(i32, num_samples), out_buffer);
    if (rc == Success) return;
    return decodeError(rc);
}

/// Spatialize a mono in ambisonics
///
/// \param InMono[in] Mono audio buffer to spatialize
/// \param DirectionX[in] X component of the direction vector
/// \param DirectionY[in] Y component of the direction vector
/// \param DirectionZ[in] Z component of the direction vector
/// \param Format[in] ambisonic format (AmbiX or FuMa)
/// \param AmbisonicOrder[in] order of ambisonics (1 or 2)
/// \param OutAmbisonic[out] Buffer to write interleaved ambisonics to (4 channels for 1st order, 9 channels for second order)
/// \param NumSamples[in] Length of the buffer in frames (InMono is this length, OutAmbisonic is either 4 or 9 times this length depending on 1st or 2nd order)
///
pub fn monoToAmbisonic(
    in_mono: []const f32,
    dir_x: f32,
    dir_y: f32,
    dir_z: f32,
    format: AmbisonicFormat,
    order: AmbisonicOrder,
    out_ambisonic: []f32,
) OvrAudioError!void {
    assert(out_ambisonic.len >= in_mono.len * order.channels());
    const rc = raw.ovrAudio_MonoToAmbisonic(in_mono.ptr, dir_x, dir_y, dir_z, format, order, out_ambisonic.ptr, @intCast(i32, in_mono.len));
    if (rc == Success) return;
    return decodeError(rc);
}

/// Opaque type definitions for audio source and context
pub const Context = opaque{
    /// Audio context configuration structure
    ///
    /// Passed to Context.create
    ///
    /// \see Context.create
    ///
    pub const Configuration = extern struct {
        /// set to size of the struct
        size: u32 = @sizeOf(@This()),
        /// maximum number of audio sources to support
        max_num_sources: u32,
        /// sample rate (16000 to 48000, but 44100 and 48000 are recommended for best quality)
        sample_rate: u32,
        /// number of samples in mono input buffers passed to spatializer
        buffer_length: u32,
    };

    /// Create an audio context for spatializing incoming sounds.
    ///
    /// Creates an audio context with the given configuration.
    ///
    /// \param pContext[out] pointer to store address of context.  NOTE: pointer must be pointing to NULL!
    /// \param pConfig[in] pointer to configuration struct describing the desired context attributes
    /// \return Returns an ovrResult indicating success or failure
    /// \see Context.destroy
    /// \see Context.Configuration
    ///
    pub fn create(config: Configuration) OvrAudioError!*Context {
        var result: ?*Context = null;
        const rc = raw.ovrAudio_CreateContext(&result, &config);
        if (rc == Success and result != null) return result.?;
        return decodeError(rc);
    }

    pub fn initialize(self: *Context, config: Configuration) OvrAudioError!void {
        const rc = raw.ovrAudio_InitializeContext(self, &config);
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Destroy a previously created audio context.
    ///
    /// \param[in] Context a valid audio context
    /// \see ovrAudio_CreateContext
    ///
    pub fn destroy(self: *Context) void {
        raw.ovrAudio_DestroyContext(self);
    }

    /// Enable/disable options in the audio context.
    ///
    /// \param Context context to use
    /// \param What specific property to enable/disable
    /// \param Enable 0 to disable, 1 to enable
    /// \return Returns an ovrResult indicating success or failure
    ///
    pub fn enable(self: *Context, what: Enable, enabled: bool) OvrAudioError!void {
        const rc = raw.ovrAudio_Enable(self, what, @boolToInt(enabled));
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Query option status in the audio context.
    ///
    /// \param Context context to use
    /// \param What specific property to query
    /// \param pEnabled addr of variable to receive the queried property status
    /// \return Returns an ovrResult indicating success or failure
    ///
    pub fn isEnabled(self: *Context, what: Enable) OvrAudioError!bool {
        var enabled: i32 = 0;
        const rc = raw.ovrAudio_IsEnabled(self, what, &enabled);
        if (rc == Success) return enabled != 0;
        return decodeError(rc);
    }

    /// Set the unit scale of game units relative to meters. (e.g. for centimeters set UnitScale = 0.01)
    ///
    /// \param UnitScale[in] unit scale value relative to meters
    ///
    pub fn setUnitScale(self: *Context, scale: f32) OvrAudioError!void {
        const rc = raw.ovrAudio_SetUnitScale(self, scale);
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Get the unit scale of game units relative to meters.
    ///
    /// \param UnitScale[out] unit scale value value relative to meters
    ///
    pub fn getUnitScale(self: *Context) OvrAudioError!f32 {
        var res: f32 = 0;
        const rc = raw.ovrAudio_GetUnitScale(self, &res);
        if (rc == Success) return res;
        return decodeError(rc);
    }

    /// Set HRTF interpolation method.
    ///
    /// NOTE: Internal use only!
    /// \param Context context to use
    /// \param InterpolationMethod method to use
    ///
    pub fn _setHRTFInterpolationMethod(self: *Context, interp: _Reserved_HRTFInterpolationMethod) OvrAudioError!void {
        const rc = raw.ovrAudio_SetHRTFInterpolationMethod(self, interp);
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Get HRTF interpolation method.
    ///
    /// NOTE: Internal use only!
    /// \param Context context to use
    /// \param InterpolationMethod method to use
    ///
    pub fn _getHRTFInterpolationMethod(self: *Context) OvrAudioError!_Reserved_HRTFInterpolationMethod {
        var res: _Reserved_HRTFInterpolationMethod = ._nearest;
        const rc = raw.ovrAudio_GetHRTFInterpolationMethod(self, &res);
        if (rc == Success) return res;
        return decodeError(rc);
    }

    /// Set box room parameters for reverberation.
    ///
    /// These parameters are used for reverberation/early reflections if
    /// ovrAudioEnable_SimpleRoomModeling is enabled.
    ///
    /// \param Context[in] context to use
    /// \param Parameters[in] pointer to ovrAudioBoxRoomParameters describing box
    /// \return Returns an ovrResult indicating success or failure
    /// \see ovrAudioBoxRoomParameters
    /// \see ovrAudio_Enable
    ///
    pub fn setSimpleBoxRoomParameters(self: *Context, params: BoxRoomParameters) OvrAudioError!void {
        const rc = raw.ovrAudio_SetSimpleBoxRoomParameters(self, &params);
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Get box room parameters for current reverberation.
    ///
    /// \param Context[in] context to use
    /// \param Parameters[out] pointer to returned ovrAudioBoxRoomParameters box description
    /// \return Returns an ovrResult indicating success or failure
    /// \see ovrAudioBoxRoomParameters
    /// \see ovrAudio_Enable
    ///
    pub fn getSimpleBoxRoomParameters(self: *Context) OvrAudioError!BoxRoomParameters {
        var params: BoxRoomParameters = undefined;
        const rc = raw.ovrAudio_GetSimpleBoxRoomParameters(self, &params);
        if (rc == Success) return params;
        return decodeError(rc);
    }


    /// Set advanced box room parameters for reverberation.
    ///
    /// These parameters are used for reverberation/early reflections if
    /// ovrAudioEnable_SimpleRoomModeling is enabled.
    ///
    /// \param Context[in] context to use
    /// \param LockToListenerPosition[in] 1 - room is centered on listener, 0 - room center is specified by RoomPosition coordinates
    /// \param RoomPositionX[in] desired X coordinate of room (if not locked to listener)
    /// \param RoomPositionY[in] desired Y coordinate of room (if not locked to listener)
    /// \param RoomPositionZ[in] desired Z coordinate of room (if not locked to listener)
    /// \param WallMaterials[in] absorption coefficients for room materials
    /// \return Returns an ovrResult indicating success or failure
    /// \see ovrAudio_SetSimpleBoxRoomParameters
    /// \see ovrAudio_Enable
    ///
    pub fn setAdvancedBoxRoomParameters(self: *Context, params: AdvancedBoxRoomParameters) OvrAudioError!void {
        const rc = raw.ovrAudio_SetAdvancedBoxRoomParameters(self, &params);
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Get advanced box room parameters for reverberation.
    ///
    /// These parameters are used for reverberation/early reflections if
    /// ovrAudioEnable_SimpleRoomModeling is enabled.
    ///
    /// \param Context[in] context to use
    /// \param LockToListenerPosition[out] 1 - room is centered on listener, 0 - room center is specified by RoomPosition coordinates
    /// \param RoomPositionX[out] desired X coordinate of room (if not locked to listener)
    /// \param RoomPositionY[out] desired Y coordinate of room (if not locked to listener)
    /// \param RoomPositionZ[out] desired Z coordinate of room (if not locked to listener)
    /// \param WallMaterials[out] absorption coefficients for room materials
    /// \return Returns an ovrResult indicating success or failure
    /// \see ovrAudio_SetAdvancedBoxRoomParameters
    /// \see ovrAudio_Enable
    ///
    pub fn getAdvancedBoxRoomParameters(self: *Context) OvrAudioError!AdvancedBoxRoomParameters {
        var params: AdvancedBoxRoomParameters = undefined;
        const rc = raw.ovrAudio_GetAdvancedBoxRoomParameters(self, &params);
        if (rc == Success) return params;
        return decodeError(rc);
    }

    /// Sets the listener's pose state as vectors, position is in game units (unit scale will be applied)
    ///
    /// If this is not set then the listener is always assumed to be facing into
    /// the screen (0,0,-1) at location (0,0,0) and that all spatialized sounds
    /// are in listener-relative coordinates.
    ///
    /// \param Context[in] context to use
    /// \param PositionX[in] X position of listener on X axis
    /// \param PositionY[in] Y position of listener on X axis
    /// \param PositionZ[in] Z position of listener on X axis
    /// \param ForwardX[in] X component of listener forward vector
    /// \param ForwardY[in] Y component of listener forward vector
    /// \param ForwardZ[in] Z component of listener forward vector
    /// \param UpX[in] X component of listener up vector
    /// \param UpY[in] Y component of listener up vector
    /// \param UpZ[in] Z component of listener up vector
    /// \return Returns an ovrResult indicating success or failure
    ///
    pub fn setListenerVectors(self: *Context, position: ovr.Vector3f, forward: ovr.Vector3f, up: ovr.Vector3f) OvrAudioError!void {
        const rc = raw.ovrAudio_SetListenerVectors(self,
            position.x, position.y, position.z,
            forward.x, forward.y, forward.z,
            up.x, up.y, up.z,
        );
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Gets the listener's pose state as vectors
    ///
    /// \param Context[in] context to use
    /// \param pPositionX[in]: addr of X position of listener on X axis
    /// \param pPositionY[in]: addr of Y position of listener on X axis
    /// \param pPositionZ[in]: addr of Z position of listener on X axis
    /// \param pForwardX[in]: addr of X component of listener forward vector
    /// \param pForwardY[in]: addr of Y component of listener forward vector
    /// \param pForwardZ[in]: addr of Z component of listener forward vector
    /// \param pUpX[in]: addr of X component of listener up vector
    /// \param pUpY[in]: addr of Y component of listener up vector
    /// \param pUpZ[in]: addr of Z component of listener up vector
    /// \return Returns an ovrResult indicating success or failure
    ///
    pub const ListenerVectors = struct {
        position: ovr.Vector3f,
        forward: ovr.Vector3f,
        up: ovr.Vector3f,
    };
    pub fn getListenerVectors(self: *Context) OvrAudioError!ListenerVectors {
        var res: ListenerVectors = undefined;
        const rc = raw.ovrAudio_GetListenerVectors(self,
            &res.position.x, &res.position.y, &res.position.z,
            &res.forward.x, &res.forward.y, &res.forward.z,
            &res.up.x, &res.up.y, &res.up.z,
        );
        if (rc == Success) return res;
        return decodeError(rc);
    }

    /// Sets the listener's pose state
    ///
    /// If this is not set then the listener is always assumed to be facing into
    /// the screen (0,0,-1) at location (0,0,0) and that all spatialized sounds
    /// are in listener-relative coordinates.
    ///
    /// \param Context[in] context to use
    /// \param PoseState[in] listener's pose state as returned by LibOVR
    /// \return Returns an ovrResult indicating success or failure
    ///
    // NO_COMMIT pub const setListenerPoseStatef = @compileError("PoseStatef is not defined.");

    // Note: there is no ovrAudio_GetListenerPoseStatef() since the pose data is not cached internally.
    // Use ovrAudio_GetListenerVectors() instead to get the listener's position and orientation info.

    /// Reset an audio source's state.
    ///
    /// Sometimes you need to reset an audio source's internal state due to a change
    /// in the incoming sound or parameters.  For example, removing any reverb
    /// tail since the incoming waveform has been swapped.
    ///
    /// \param Context context to use
    /// \param Sound index of sound (0..NumSources-1)
    /// \return Returns an ovrResult indicating success or failure
    ///
    pub fn resetAudioSource(self: *Context, sound: u32) OvrAudioError!void {
        const rc = raw.ovrAudio_ResetAudioSource(self, @intCast(i32, sound));
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Sets the position of an audio source in game units (unit scale will be applied).  Use "OVR" coordinate system (same as pose).
    ///
    /// \param Context context to use
    /// \param Sound index of sound (0..NumSources-1)
    /// \param X position of sound on X axis
    /// \param Y position of sound on Y axis
    /// \param Z position of sound on Z axis
    /// \return Returns an ovrResult indicating success or failure
    /// \see ovrAudio_SetListenerPoseStatef
    /// \see ovrAudio_SetAudioSourceRange
    ///
    pub fn setAudioSourcePos(self: *Context, sound: u32, pos: ovr.Vector3f) OvrAudioError!void {
        const rc = raw.ovrAudio_SetAudioSourcePos(self, @intCast(i32, sound), pos.x, pos.y, pos.z);
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Gets the position of an audio source.  Use "OVR" coordinate system (same as pose).
    ///
    /// \param Context context to use
    /// \param Sound index of sound (0..NumSources-1)
    /// \param pX address of position of sound on X axis
    /// \param pY address of position of sound on Y axis
    /// \param pZ address of position of sound on Z axis
    /// \return Returns an ovrResult indicating success or failure
    /// \see ovrAudio_SetListenerPoseStatef
    /// \see ovrAudio_SetAudioSourceRange
    ///
    pub fn getAudioSourcePos(self: *Context, sound: u32) OvrAudioError!ovr.Vector3f {
        var result: ovr.Vector3f = undefined;
        const rc = raw.ovrAudio_GetAudioSourcePos(self, @intCast(i32, sound), &result.x, &result.y, &result.z);
        if (rc == Success) return result;
        return decodeError(rc);
    }

    /// Sets the min and max range of the audio source.
    ///
    /// \param Context context to use
    /// \param Sound index of sound (0..NumSources-1)
    /// \param RangeMin min range in meters (full gain)
    /// \param RangeMax max range in meters
    /// \return Returns an ovrResult indicating success or failure
    /// \see ovrAudio_SetListenerPoseStatef
    /// \see ovrAudio_SetAudioSourcePos
    ///
    pub fn setAudioSourceRange(self: *Context, sound: u32, range_min: f32, range_max: f32) OvrAudioError!void {
        const rc = raw.ovrAudio_SetAudioSourceRange(self, @intCast(i32, sound), range_min, range_max);
        if (rc == Success) return;
        return decodeError(rc);
    }

    const AudioSourceRange = struct {
        min: f32,
        max: f32,
    };
    /// Gets the min and max range of the audio source.
    ///
    /// \param Context context to use
    /// \param Sound index of sound (0..NumSources-1)
    /// \param pRangeMin addr of variable to receive the returned min range parameter (in meters).
    /// \param pRangeMax addr of variable to receive the returned max range parameter (in meters).
    /// \return Returns an ovrResult indicating success or failure
    /// \see ovrAudio_SetListenerPoseStatef
    /// \see ovrAudio_SetAudioSourcePos
    /// \see ovrAudio_SetAudioSourceRange
    ///
    pub fn getAudioSourceRange(self: *Context, sound: u32) OvrAudioError!AudioSourceRange {
        var result: AudioSourceRange = undefined;
        const rc = raw.ovrAudio_GetAudioSourceRange(self, @intCast(i32, sound), &result.min, &result.max);
        if (rc == Success) return result;
        return decodeError(rc);
    }

    /// Sets the radius of the audio source for volumetric sound sources. Set a radius of 0 to make it a point source.
    ///
    /// \param Context context to use
    /// \param Sound index of sound (0..NumSources-1)
    /// \param Radius source radius in meters
    /// \return Returns an ovrResult indicating success or failure
    /// \see ovrAudio_SetListenerPoseStatef
    /// \see ovrAudio_SetAudioSourcePos
    ///
    pub fn setAudioSourceRadius(self: *Context, sound: u32, radius: f32) OvrAudioError!void {
        const rc = raw.ovrAudio_SetAudioSourceRadius(self, @intCast(i32, sound), radius);
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Gets the radius of the audio source for volumetric sound sources.
    ///
    /// \param Context context to use
    /// \param Sound index of sound (0..NumSources-1)
    /// \param pRadiusMin addr of variable to receive the returned radius parameter (in meters).
    /// \return Returns an ovrResult indicating success or failure
    /// \see ovrAudio_SetListenerPoseStatef
    /// \see ovrAudio_SetAudioSourcePos
    /// \see ovrAudio_SetAudioSourceRadius
    ///
    pub fn getAudioSourceRadius(self: *Context, sound: u32) OvrAudioError!f32 {
        var radius: f32 = 0;
        const rc = raw.ovrAudio_GetAudioSourceRadius(self, @intCast(i32, sound), &radius);
        if (rc == Success) return radius;
        return decodeError(rc);
    }

    /// Sets the reverb wet send level for audio source
    ///
    /// \param Context context to use
    /// \param Sound index of sound (0..NumSources-1)
    /// \param Level send level in linear scale (0.0f to 1.0f)
    /// \return Returns an ovrResult indicating success or failure
    /// \see ovrAudio_SetListenerPoseStatef
    /// \see ovrAudio_SetAudioSourcePos
    ///
    pub fn setAudioReverbSendLevel(self: *Context, sound: u32, level: f32) OvrAudioError!void {
        const rc = raw.ovrAudio_SetAudioReverbSendLevel(self, @intCast(i32, sound), level);
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Gets the the reverb wet send level for audio source
    ///
    /// \param Context context to use
    /// \param Sound index of sound (0..NumSources-1)
    /// \param pLevel addr of variable to receive the currently set send level
    /// \return Returns an ovrResult indicating success or failure
    /// \see ovrAudio_SetListenerPoseStatef
    /// \see ovrAudio_SetAudioSourcePos
    /// \see ovrAudio_SetAudioSourceRadius
    ///
    pub fn getAudioReverbSendLevel(self: *Context, sound: u32) OvrAudioError!f32 {
        var level: f32 = 0;
        const rc = raw.ovrAudio_GetAudioReverbSendLevel(self, @intCast(i32, sound), &level);
        if (rc == Success) return level;
        return decodeError(rc);
    }


    /// Sets an audio source's flags.
    ///
    /// \param Context context to use
    /// \param Sound index of sound (0..NumSources-1)
    /// \param Flags a logical OR of ovrAudioSourceFlag enumerants
    /// \return Returns an ovrResult indicating success or failure
    ///
    pub fn setAudioSourceFlags(self: *Context, sound: u32, flags: SourceFlags) OvrAudioError!void {
        const rc = raw.ovrAudio_SetAudioSourceFlags(self, @intCast(i32, sound), @bitCast(u32, flags));
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Gets an audio source's flags.
    ///
    /// \param Context context to use
    /// \param Sound index of sound (0..NumSources-1)
    /// \param pFlags addr of returned flags (a logical OR of ovrAudioSourceFlag enumerants)
    /// \return Returns an ovrResult indicating success or failure
    ///
    pub fn getAudioSourceFlags(self: *Context, sound: u32) OvrAudioError!SourceFlags {
        var result: u32 = 0;
        const rc = raw.ovrAudio_GetAudioSourceFlags(self, @intCast(i32, sound), &result);
        if (rc == Success) return @bitCast(SourceFlags, result);
        return decodeError(rc);
    }

    /// Set the attenuation mode for a sound source.
    ///
    /// Sounds can have their volume attenuated by distance based on different methods.
    ///
    /// \param Context context to use
    /// \param Sound index of sound (0..NumSources-1)
    /// \param Mode attenuation mode to use
    /// \param FixedScale attenuation constant used for fixed attenuation mode
    /// \return Returns an ovrResult indicating success or failure
    ///
    pub fn setAudioSourceAttenuationMode(self: *Context, sound: u32, mode: SourceAttenuationMode, source_gain: f32) OvrAudioError!void {
        const rc = raw.ovrAudio_SetAudioSourceAttenuationMode(self, @intCast(i32, sound), mode, source_gain);
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Get the attenuation mode for a sound source.
    ///
    /// Sounds can have their volume attenuated by distance based on different methods.
    ///
    /// \param Context context to use
    /// \param Sound index of sound (0..NumSources-1)
    /// \param pMode addr of returned attenuation mode in use
    /// \param pFixedScale addr of returned attenuation constant used for fixed attenuation mode
    /// \return Returns an ovrResult indicating success or failure
    ///
    pub fn getAudioSourceAttenuationMode(self: *Context, sound: u32) OvrAudioError!AttenuationParams {
        var res: AttenuationParams = undefined;
        const rc = raw.ovrAudio_GetAudioSourceAttenuationMode(self, @intCast(i32, sound), &res.mode, &res.source_gain);
        if (rc == Success) return res;
        return decodeError(rc);
    }
    pub const AttenuationParams = struct {
        mode: SourceAttenuationMode,
        source_gain: f32,
    };

    /// Get the overall gain for a sound source.
    ///
    /// The gain after all attenatuation is applied, this can be used for voice prioritization and virtualization
    ///
    /// \param Context context to use
    /// \param Sound index of sound (0..NumSources-1)
    /// \param pMode addr of returned attenuation mode in use
    /// \param pFixedScale addr of returned attenuation constant used for fixed attenuation mode
    /// \return Returns an ovrResult indicating success or failure
    ///
    pub fn getAudioSourceOverallGain(self: *Context, sound: u32) OvrAudioError!f32 {
        var gain: f32 = 0;
        const rc = raw.ovrAudio_GetAudioSourceOverallGain(self, @intCast(i32, sound), &gain);
        if (rc == Success) return gain;
        return decodeError(rc);
    }

    /// Spatialize a mono audio source to interleaved stereo output.
    ///
    /// \param Context[in] context to use
    /// \param Sound[in] index of sound (0..NumSources-1)
    /// \param OutStatus[out] bitwise OR of flags indicating status of currently playing sound
    /// \param Dst[out] pointer to stereo interleaved floating point destination buffer
    /// \param Src[in] pointer to mono floating point buffer to spatialize
    /// \return Returns an ovrResult indicating success or failure
    ///
    /// \see ovrAudio_SpatializeMonoSourceLR
    ///
    pub fn spatializeMonoSourceInterleaved(
        self: *Context,
        sound: u32,
        out_interleaved: [*]f32,
        in_mono: [*]const f32,
    ) OvrAudioError!SpatializationStatus {
        var status: u32 = 0;
        const rc = raw.ovrAudio_SpatializeMonoSourceInterleaved(self, @intCast(i32, sound), &status, out_interleaved, in_mono);
        if (rc == Success) return @bitCast(SpatializationStatus, status);
        return decodeError(rc);
    }

    /// Spatialize a mono audio source to separate left and right output buffers.
    ///
    /// \param Context[in] context to use
    /// \param Sound[in] index of sound (0..NumSources-1)
    /// \param OutStatus[out] bitwise OR of flags indicating status of currently playing sound
    /// \param DstLeft[out]  pointer to floating point left channel buffer
    /// \param DstRight[out] pointer to floating point right channel buffer
    /// \param Src[in] pointer to mono floating point buffer to spatialize
    /// \return Returns an ovrResult indicating success or failure
    ///
    /// \see ovrAudio_SpatializeMonoSourceInterleaved
    ///
    pub fn spatializeMonoSourceLR(
        self: *Context,
        sound: u32,
        out_left: [*]f32,
        out_right: [*]f32,
        in_mono: [*]const f32,
    ) OvrAudioError!SpatializationStatus {
        var status: u32 = 0;
        const rc = raw.ovrAudio_SpatializeMonoSourceLR(self, @intCast(i32, sound), &status, out_left, out_right, in_mono);
        if (rc == Success) return @bitCast(SpatializationStatus, status);
        return decodeError(rc);
    }

    /// Mix shared reverb into buffer
    ///
    /// \param Context[in] context to use
    /// \param OutStatus[out] bitwise OR of flags indicating status of currently playing sound
    /// \param OutLeft[out] pointer to floating point left channel buffer to mix into (MUST CONTAIN VALID AUDIO OR SILENCE)
    /// \param OutRight[out] pointer to floating point right channel buffer to mix into (MUST CONTAIN VALID AUDIO OR SILENCE)
    /// \return Returns an ovrResult indicating success or failure
    ///
    pub fn mixInSharedReverbLR(
        self: *Context,
        out_left: [*]f32,
        out_right: [*]f32,
    ) OvrAudioError!SpatializationStatus {
        var status: u32 = 0;
        const rc = raw.ovrAudio_MixInSharedReverbLR(self, &status, out_left, out_right);
        if (rc == Success) return @bitCast(SpatializationStatus, status);
        return decodeError(rc);
    }

    /// Mix shared reverb into interleaved buffer
    ///
    /// \param Context[in] context to use
    /// \param OutStatus[out] bitwise OR of flags indicating status of currently playing sound
    /// \param DstInterleaved[out] pointer to interleaved floating point left&right channels buffer to mix into (MUST CONTAIN VALID AUDIO OR SILENCE)
    /// \return Returns an ovrResult indicating success or failure
    ///
    pub fn mixInSharedReverbInterleaved(
        self: *Context,
        out_interleaved: [*]f32,
    ) OvrAudioError!SpatializationStatus {
        var status: u32 = 0;
        const rc = raw.ovrAudio_MixInSharedReverbInterleaved(self, &status, out_interleaved);
        if (rc == Success) return @bitCast(SpatializationStatus, status);
        return decodeError(rc);
    }

    /// Set shared reverb wet level
    ///
    /// \param Context[in] context to use
    /// \param Level[out] linear value to scale global reverb level by
    /// \return Returns an ovrResult indicating success or failure
    ///
    pub fn setSharedReverbWetLevel(self: *Context, level: f32) OvrAudioError!void {
        const rc = raw.ovrAudio_SetSharedReverbWetLevel(self, level);
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Get shared reverb wet level
    ///
    /// \param Context[in] context to use
    /// \param Level[out] linear value currently set to scale global reverb level by
    /// \return Returns an ovrResult indicating success or failure
    ///
    pub fn getSharedReverbWetLevel(self: *Context) OvrAudioError!f32 {
        var level: f32 = 0;
        const rc = raw.ovrAudio_GetSharedReverbWetLevel(self, &level);
        if (rc == Success) return level;
        return decodeError(rc);
    }

    /// Set user headRadius.
    ///
    /// NOTE: This API is intended to let you set user configuration parameters that
    /// may assist with spatialization.
    ///
    /// \param Context[in] context to use
    /// \param Config[in] configuration state
    pub fn setHeadRadius(self: *Context, head_radius: f32) OvrAudioError!void {
        const rc = raw.ovrAudio_SetHeadRadius(self, head_radius);
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Set user configuration.
    ///
    /// NOTE: This API is intended to let you set user configuration parameters that
    /// may assist with spatialization.
    ///
    /// \param Context[in] context to use
    /// \param Config[in] configuration state
    pub fn getHeadRadius(self: *Context) OvrAudioError!f32 {
        var head_radius: f32 = 0;
        const rc = raw.ovrAudio_GetHeadRadius(self, &head_radius);
        if (rc == Success) return head_radius;
        return decodeError(rc);
    }

    /// Retrieve a performance counter.
    ///
    /// \param Context[in] context to use
    /// \param Counter[in] the counter to retrieve
    /// \param Count[out] destination for count variable (number of times that counter was updated)
    /// \param TimeMicroSeconds destination for total time spent in that performance counter
    /// \return Returns an ovrResult indicating success or failure
    /// \see ovrAudio_ResetPerformanceCounter
    ///
    pub fn getPerformanceCounter(self: *Context, counter: PerformanceCounter) OvrAudioError!PerfCounterState {
        var res: PerfCounterState = undefined;
        const rc = raw.ovrAudio_GetPerformanceCounter(self, counter, &res.count, &res.time_micros);
        if (rc == Success) return res;
        return decodeError(rc);
    }
    pub const PerfCounterState = struct {
        count: i64,
        time_micros: f64,
    };

    /// Reset a performance counter.
    ///
    /// \param Context[in] context to use
    /// \param Counter[in] the counter to retrieve
    /// \see ovrAudio_ResetPerformanceCounter
    ///
    pub fn resetPerformanceCounter(self: *Context, counter: PerformanceCounter) OvrAudioError!void {
        const rc = raw.ovrAudio_ResetPerformanceCounter(self, counter);
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Create an ambisonic stream instance for spatializing B-format ambisonic audio
    ///
    /// \param SampleRate[in] sample rate of B-format signal (16000 to 48000, but 44100 and 48000 are recommended for best quality)
    /// \param AudioBufferLength[in] size of audio buffers
    /// \param pContext[out] pointer to store address of stream.
    ///
    pub fn createAmbisonicStream(
        self: *Context,
        sample_rate: u32,
        audio_buffer_length: usize,
        format: AmbisonicFormat,
        order: AmbisonicOrder,
    ) OvrAudioError!*AmbisonicStream {
        var res: ?*AmbisonicStream = null;
        const rc = raw.ovrAudio_CreateAmbisonicStream(self, @intCast(i32, sample_rate), @intCast(i32, audio_buffer_length), format, order, &res);
        if (rc == Success and res != null) return res.?;
        return decodeError(rc);
    }

    /// Spatialize ambisonic stream
    ///
    /// \param Src[in] pointer to interleaved floating point ambisonic buffer to spatialize
    /// \param Dst[out] pointer to stereo interleaved floating point destination buffer
    ///
    pub fn processAmbisonicStreamInterleaved(
        self: *Context,
        stream: *AmbisonicStream,
        in_ambisonic_data: [*]const f32,
        out_interleaved: [*]f32,
        num_samples: usize,
    ) OvrAudioError!void {
        const rc = raw.ovrAudio_ProcessAmbisonicStreamInterleaved(self, stream, in_ambisonic_data, out_interleaved, @intCast(i32, num_samples));
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Enable the Oculus Audio profiler to connect to the game and monitor the CPU usage live
    ///
    /// \param Context[in] context to use
    /// \param Enabled[in] whether the profiler is enabled
    ///
    pub fn setProfilerEnabled(self: *Context, enabled: bool) OvrAudioError!void {
        const rc = raw.ovrAudio_SetProfilerEnabled(self, @boolToInt(enabled));
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Set the network port for the Oculus Audio profiler
    ///
    /// \param Context[in] context to use
    /// \param Port[in] port number to use in the range 0 - 65535 (default is 2121)
    ///
    pub fn setProfilerPort(self: *Context, port: u16) OvrAudioError!void {
        const rc = raw.ovrAudio_SetProfilerPort(self, port);
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Explicitly set the reflection model, this can be used to A/B test the algorithms
    ///
    /// \param Context[in] context to use
    /// \param Model[in] The reflection model to use (default is Automatic)
    ///
    /// \see ovrAudioReflectionModel
    pub fn setReflectionModel(self: *Context, model: ReflectionModel) OvrAudioError!void {
        const rc = raw.ovrAudio_SetReflectionModel(self, model);
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Assign a callback for raycasting into the game geometry
    ///
    /// \param Context[in] context to use
    /// \param Callback[in] pointer to an implementation of OVRA_RAYCAST_CALLBACK
    /// \param pctx[in] address of user data pointer to be passed into the callback
    ///
    pub fn assignRaycastCallback(self: *Context, callback: ?RaycastCallback, pctx: ?*const volatile anyopaque) OvrAudioError!void {
        const rc = raw.ovrAudio_AssignRaycastCallback(self, callback, pctx);
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Set the number of ray casts per second are used for dynamic modeling, more rays mean more accurate and responsive modelling but will reduce performance
    ///
    /// \param Context[in] context to use
    /// \param RaysPerSecond[in] number of ray casts per second, default = 256
    ///
    pub fn setDynamicRoomRaysPerSecond(self: *Context, rays_per_second: u32) OvrAudioError!void {
        const rc = raw.ovrAudio_SetDynamicRoomRaysPerSecond(self, @intCast(i32, rays_per_second));
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Set the speed which the dynamic room interpolates, higher values will update more quickly but less smooth
    ///
    /// \param Context[in] context to use
    /// \param InterpSpeed[in] speed which it interpolates (0.0 - 1.0) default = 0.9
    ///
    pub fn setDynamicRoomInterpSpeed(self: *Context, interp_speed: f32) OvrAudioError!void {
        const rc = raw.ovrAudio_SetDynamicRoomInterpSpeed(self, interp_speed);
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Set the maximum distance to the wall for dynamic room modeling to constrain the size
    ///
    /// \param Context[in] context to use
    /// \param MaxWallDistance[in] distance to wall in meters, default = 50
    ///
    pub fn setDynamicRoomMaxWallDistance(self: *Context, max_wall_distance: f32) OvrAudioError!void {
        const rc = raw.ovrAudio_SetDynamicRoomMaxWallDistance(self, max_wall_distance);
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Set the size of the cache which holds a history of the rays cast, a larger value will have more points making it more stable but less responsive
    ///
    /// \param Context[in] context to use
    /// \param RayCacheSize[in] number of rays to cache, default = 512
    ///
    pub fn setDynamicRoomRaysRayCacheSize(self: *Context, ray_cache_size: u32) OvrAudioError!void {
        const rc = raw.ovrAudio_SetDynamicRoomRaysRayCacheSize(self, @intCast(i32, ray_cache_size));
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Retrieves the dimensions of the dynamic room model
    ///
    /// \param Context[in] context to use
    /// \param RoomDimensions[out] X, Y, and Z dimensions of the room
    /// \param ReflectionsCoefs[out] the reflection coefficients of the walls
    /// \param Position[out] the world position of the center of the room
    ///
    pub fn getRoomDimensions(self: *Context) OvrAudioError!RoomDimensions {
        var result: RoomDimensions = undefined;
        const rc = raw.ovrAudio_GetRoomDimensions(self, &result.dimensions, &result.reflection_coefs, &result.center_pos);
        if (rc == Success) return result;
        return decodeError(rc);
    }
    pub const RoomDimensions = struct {
        dimensions: [3]f32,
        reflection_coefs: [6]f32,
        center_pos: ovr.Vector3f,
    };

    /// Retrieves the cache of ray cast hits that are being used to estimate the room, this is useful for debugging rays hitting the wrong objects
    ///
    /// \param Context[in] context to use
    /// \param Points[out] array of points where the rays hit geometry
    /// \param Normals[out] array of normals
    /// \param Length[int] the length of the points and normals array (both should be the same length)
    ///
    pub fn getRaycastHits(self: *Context, points: []ovr.Vector3f, normals: []ovr.Vector3f) OvrAudioError!void {
        assert(points.len == normals.len);
        const rc = raw.ovrAudio_GetRaycastHits(self, points.ptr, normals.ptr, @intCast(i32, points.len));
        if (rc == Success) return;
        return decodeError(rc);
    }

    pub usingnamespace if (has_geometry_api) geometry.context_funcs else empty;
};

pub const AmbisonicStream = opaque{
    /// Reset a previously created ambisonic stream for re-use
    ///
    /// \param[in] Context a valid ambisonic stream
    ///
    pub fn reset(self: *AmbisonicStream) OvrAudioError!void {
        const rc = raw.ovrAudio_ResetAmbisonicStream(self);
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Destroy a previously created ambisonic stream.
    ///
    /// \param[in] Context a valid ambisonic stream
    /// \see ovrAudio_CreateAmbisonicStream
    ///
    pub fn destroy(self: *AmbisonicStream) OvrAudioError!void {
        const rc = raw.ovrAudio_DestroyAmbisonicStream(self);
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Sets the render mode for the ambisonic stream.
    ///
    /// \param[in] Context a valid ambisonic stream
    /// \see ovrAudioAmbisonicRenderMode
    ///
    pub fn setRenderMode(self: *AmbisonicStream, mode: AmbisonicRenderMode) OvrAudioError!void {
        const rc = raw.ovrAudio_SetAmbisonicRenderMode(self, mode);
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Sets the render mode for the ambisonic stream.
    ///
    /// \param[in] Context a valid ambisonic stream
    /// \see ovrAudioAmbisonicRenderMode
    ///
    pub fn getRenderMode(self: *AmbisonicStream) OvrAudioError!AmbisonicRenderMode {
        var res: AmbisonicRenderMode = undefined;
        const rc = raw.ovrAudio_GetAmbisonicRenderMode(self, &res);
        if (rc == Success) return res;
        return decodeError(rc);
    }

    /// Set orientation for ambisonic stream
    ///
    /// \param LookDirectionX[in] X component of the source direction vector
    /// \param LookDirectionY[in] Y component of the source direction vector
    /// \param LookDirectionZ[in] Z component of the source direction vector
    /// \param UpDirectionX[in] X component of the source up vector
    /// \param UpDirectionY[in] Y component of the source up vector
    /// \param UpDirectionZ[in] Z component of the source up vector
    ///
    pub fn setOrientation(self: *AmbisonicStream, look_dir: ovr.Vector3f, up_dir: ovr.Vector3f) OvrAudioError!void {
        const rc = raw.ovrAudio_SetAmbisonicOrientation(self, look_dir.x, look_dir.y, look_dir.z, up_dir.x, up_dir.y, up_dir.z);
        if (rc == Success) return;
        return decodeError(rc);
    }

    /// Get orientation for ambisonic stream
    ///
    /// \param pLookDirectionX[in] address of the X component of the source direction vector
    /// \param pLookDirectionY[in] address of the Y component of the source direction vector
    /// \param pLookDirectionZ[in] address of the Z component of the source direction vector
    /// \param pUpDirectionX[in] address of the X component of the source up vector
    /// \param pUpDirectionY[in] address of the Y component of the source up vector
    /// \param pUpDirectionZ[in] address of the Z component of the source up vector
    ///
    pub fn getOrientation(self: *AmbisonicStream) OvrAudioError!Orientation {
        var res: Orientation = undefined;
        const rc = raw.ovrAudio_GetAmbisonicOrientation(self, &res.look_dir.x, &res.look_dir.y, &res.look_dir.z, &res.up_dir.x, &res.up_dir.y, &res.up_dir.z);
        if (rc == Success) return res;
        return decodeError(rc);
    }
    const Orientation = struct {
        look_dir: ovr.Vector3f,
        up_dir: ovr.Vector3f,
    };
};

pub const raw = struct {
    pub inline fn ovrAudio_Initialize() Result { return Success; }
    pub inline fn ovrAudio_Shutdown() Result { return Success; }
    pub extern fn ovrAudio_GetVersion(major: *i32, minor: *i32, patch: *i32) callconv(.C) ?[*:0]const u8;
    pub extern fn ovrAudio_AllocSamples(num_samples: i32) callconv(.C) ?[*]f32;
    pub extern fn ovrAudio_FreeSamples(samples: [*]f32) callconv(.C) void;
    pub extern fn ovrAudio_GetTransformFromPose(
        pose: *const ovr.Posef,
        vx: *[3]f32,
        vy: *[3]f32,
        vz: *[3]f32,
        pos: *[3]f32,
    ) Result;
    pub extern fn ovrAudio_ProcessQuadBinaural(
        forward_lr: [*]f32,
        right_lr: [*]f32,
        back_lr: [*]f32,
        left_lr: [*]f32,
        look_dir_x: f32,
        look_dir_y: f32,
        look_dir_z: f32,
        num_samples: i32,
        out_buffer: [*]f32,
    ) Result;
    pub extern fn ovrAudio_MonoToAmbisonic(
        in_mono: [*]const f32,
        dir_x: f32,
        dir_y: f32,
        dir_z: f32,
        format: AmbisonicFormat,
        order: AmbisonicOrder,
        out_ambisonic: [*]f32,
        num_samples: i32,
    ) Result;

    pub extern fn ovrAudio_CreateContext(context: *?*Context, config: *const Context.Configuration) callconv(.C) Result;
    pub extern fn ovrAudio_InitializeContext(context: *Context, config: *const Context.Configuration) callconv(.C) Result;
    pub extern fn ovrAudio_DestroyContext(context: *Context) callconv(.C) void;
    pub extern fn ovrAudio_Enable(context: *Context, what: Enable, enable: i32) callconv(.C) Result;
    pub extern fn ovrAudio_IsEnabled(context: *Context, what: Enable, pEnabled: *i32) callconv(.C) Result;
    pub extern fn ovrAudio_SetUnitScale(context: *Context, unit_scale: f32) callconv(.C) Result;
    pub extern fn ovrAudio_GetUnitScale(context: *Context, out_unit_scale: *f32) callconv(.C) Result;
    pub extern fn ovrAudio_SetHRTFInterpolationMethod(context: *Context, interpolation: _Reserved_HRTFInterpolationMethod) callconv(.C) Result;
    pub extern fn ovrAudio_GetHRTFInterpolationMethod(context: *Context, out_interpolation_method: *_Reserved_HRTFInterpolationMethod) callconv(.C) Result;
    pub extern fn ovrAudio_SetSimpleBoxRoomParameters(context: *Context, parameters: *const BoxRoomParameters) callconv(.C) Result;
    pub extern fn ovrAudio_GetSimpleBoxRoomParameters(context: *Context, out_parameters: *BoxRoomParameters) callconv(.C) Result;
    pub extern fn ovrAudio_SetAdvancedBoxRoomParameters(context: *Context, parameters: *const AdvancedBoxRoomParameters) callconv(.C) Result;
    pub extern fn ovrAudio_GetAdvancedBoxRoomParameters(context: *Context, out_parameters: *AdvancedBoxRoomParameters) callconv(.C) Result;
    pub extern fn ovrAudio_SetListenerVectors(
        context: *Context,
        pos_x: f32,
        pos_y: f32,
        pos_z: f32,
        forward_x: f32,
        forward_y: f32,
        forward_z: f32,
        up_x: f32,
        up_y: f32,
        up_z: f32,
    ) callconv(.C) Result;
    pub extern fn ovrAudio_GetListenerVectors(
        context: *Context,
        out_pos_x: *f32,
        out_pos_y: *f32,
        out_pos_z: *f32,
        out_forward_x: *f32,
        out_forward_y: *f32,
        out_forward_z: *f32,
        out_up_x: *f32,
        out_up_y: *f32,
        out_up_z: *f32,
    ) callconv(.C) Result;
    pub extern fn ovrAudio_SetListenerPoseStatef(context: *Context, pose_state: *const anyopaque) callconv(.C) Result;
    pub extern fn ovrAudio_ResetAudioSource(context: *Context, sound: i32) callconv(.C) Result;
    pub extern fn ovrAudio_SetAudioSourcePos(context: *Context, sound: i32, x: f32, y: f32, z: f32) callconv(.C) Result;
    pub extern fn ovrAudio_GetAudioSourcePos(context: *Context, sound: i32, out_x: *f32, out_y: *f32, out_z: *f32) callconv(.C) Result;
    pub extern fn ovrAudio_SetAudioSourceRange(context: *Context, sound: i32, range_min: f32, range_max: f32) callconv(.C) Result;
    pub extern fn ovrAudio_GetAudioSourceRange(context: *Context, sound: i32, out_range_min: *f32, out_range_max: *f32) callconv(.C) Result;
    pub extern fn ovrAudio_SetAudioSourceRadius(context: *Context, sound: i32, radius: f32) callconv(.C) Result;
    pub extern fn ovrAudio_GetAudioSourceRadius(context: *Context, sound: i32, out_radius: *f32) callconv(.C) Result;
    pub extern fn ovrAudio_SetAudioReverbSendLevel(context: *Context, sound: i32, level: f32) callconv(.C) Result;
    pub extern fn ovrAudio_GetAudioReverbSendLevel(context: *Context, sound: i32, out_level: *f32) callconv(.C) Result;
    pub extern fn ovrAudio_SetAudioSourceFlags(context: *Context, sound: i32, flags: u32) callconv(.C) Result;
    pub extern fn ovrAudio_GetAudioSourceFlags(context: *Context, sound: i32, out_flags: *u32) callconv(.C) Result;
    pub extern fn ovrAudio_SetAudioSourceAttenuationMode(context: *Context, sound: i32, mode: SourceAttenuationMode, gain: f32) callconv(.C) Result;
    pub extern fn ovrAudio_GetAudioSourceAttenuationMode(context: *Context, sound: i32, out_mode: *SourceAttenuationMode, out_gain: *f32) callconv(.C) Result;
    pub extern fn ovrAudio_GetAudioSourceOverallGain(context: *Context, sound: i32, out_gain: *f32) callconv(.C) Result;
    pub extern fn ovrAudio_SpatializeMonoSourceInterleaved(
        context: *Context,
        sound: i32,
        out_status: *u32,
        out_interleaved: [*]f32,
        in_mono: [*]const f32,
    ) callconv(.C) Result;
    pub extern fn ovrAudio_SpatializeMonoSourceLR(
        context: *Context,
        sound: i32,
        out_status: *u32,
        out_left: [*]f32,
        out_right: [*]f32,
        in_mono: [*]const f32,
    ) callconv(.C) Result;
    pub extern fn ovrAudio_MixInSharedReverbLR(
        context: *Context,
        out_status: *u32,
        out_left: [*]f32,
        out_right: [*]f32,
    ) callconv(.C) Result;
    pub extern fn ovrAudio_MixInSharedReverbInterleaved(
        context: *Context,
        out_status: *u32,
        out_interleaved: [*]f32,
    ) callconv(.C) Result;
    pub extern fn ovrAudio_SetSharedReverbWetLevel(context: *Context, level: f32) callconv(.C) Result;
    pub extern fn ovrAudio_GetSharedReverbWetLevel(context: *Context, out_level: *f32) callconv(.C) Result;
    pub extern fn ovrAudio_SetHeadRadius(context: *Context, head_radius: f32) callconv(.C) Result;
    pub extern fn ovrAudio_GetHeadRadius(context: *Context, out_head_radius: *f32) callconv(.C) Result;
    pub extern fn ovrAudio_GetPerformanceCounter(context: *Context, counter: PerformanceCounter, out_count: *i64, out_time_micros: *f64) callconv(.C) Result;
    pub extern fn ovrAudio_ResetPerformanceCounter(context: *Context, counter: PerformanceCounter) callconv(.C) Result;
    pub extern fn ovrAudio_CreateAmbisonicStream(
        context: *Context,
        sample_rate: i32,
        audio_buffer_length: i32,
        format: AmbisonicFormat,
        order: AmbisonicOrder,
        out_stream: *?*AmbisonicStream,
    ) callconv(.C) Result;
    pub extern fn ovrAudio_ProcessAmbisonicStreamInterleaved(
        context: *Context,
        stream: *AmbisonicStream,
        in_ambisonic: [*]const f32,
        out_interleaved: [*]f32,
        num_samples: i32,
    ) callconv(.C) Result;
    pub extern fn ovrAudio_SetProfilerEnabled(context: *Context, enabled: i32) callconv(.C) Result;
    pub extern fn ovrAudio_SetProfilerPort(context: *Context, port: i32) callconv(.C) Result;
    pub extern fn ovrAudio_SetReflectionModel(context: *Context, model: ReflectionModel) callconv(.C) Result;
    pub extern fn ovrAudio_AssignRaycastCallback(context: *Context, callback: ?RaycastCallback, pctx: ?*const volatile anyopaque) callconv(.C) Result;
    pub extern fn ovrAudio_SetDynamicRoomRaysPerSecond(context: *Context, rays_per_second: i32) callconv(.C) Result;
    pub extern fn ovrAudio_SetDynamicRoomInterpSpeed(context: *Context, interp_speed: f32) callconv(.C) Result;
    pub extern fn ovrAudio_SetDynamicRoomMaxWallDistance(context: *Context, max_wall_distance: f32) callconv(.C) Result;
    pub extern fn ovrAudio_SetDynamicRoomRaysRayCacheSize(context: *Context, ray_cache_size: i32) callconv(.C) Result;
    pub extern fn ovrAudio_GetRoomDimensions(context: *Context, out_dimensions: *[3]f32, out_reflection_coefs: *[6]f32, out_center_pos: *ovr.Vector3f) callconv(.C) Result;
    pub extern fn ovrAudio_GetRaycastHits(context: *Context, points: [*]ovr.Vector3f, normals: [*]ovr.Vector3f, length: i32) callconv(.C) Result;

    pub extern fn ovrAudio_ResetAmbisonicStream(stream: *AmbisonicStream) callconv(.C) Result;
    pub extern fn ovrAudio_DestroyAmbisonicStream(stream: *AmbisonicStream) callconv(.C) Result;
    pub extern fn ovrAudio_SetAmbisonicRenderMode(stream: *AmbisonicStream, mode: AmbisonicRenderMode) callconv(.C) Result;
    pub extern fn ovrAudio_GetAmbisonicRenderMode(stream: *AmbisonicStream, out_mode: *AmbisonicRenderMode) callconv(.C) Result;
    pub extern fn ovrAudio_SetAmbisonicOrientation(
        stream: *AmbisonicStream,
        look_dir_x: f32,
        look_dir_y: f32,
        look_dir_z: f32,
        up_dir_x: f32,
        up_dir_y: f32,
        up_dir_z: f32,
    ) callconv(.C) Result;
    pub extern fn ovrAudio_GetAmbisonicOrientation(
        stream: *AmbisonicStream,
        out_look_dir_x: *f32,
        out_look_dir_y: *f32,
        out_look_dir_z: *f32,
        out_up_dir_x: *f32,
        out_up_dir_y: *f32,
        out_up_dir_z: *f32,
    ) callconv(.C) Result;

    pub const geometry = audio.geometry.raw_geometry;
    pub usingnamespace if (has_geometry_api) @This().geometry else empty;
};

pub usingnamespace if (has_geometry_api) geometry else empty;

//*********************************************************************************//
/// Geometry API
/// Only available on Windows,
/// all other platforms will return Error.AudioUnsupportedFeature.
/// These decls are available in the ovr.audio namespace on Windows
/// targets, and in the ovr.audio.geometry namespace for all targets.
/// ovr.audio.has_geometry_api can be checked at compile time to see
/// if the geometry api is available.
pub const geometry = struct {
    /// \brief A handle to a material that applies filtering to reflected and transmitted sound. 0/NULL/nullptr represent an invalid handle. */
    pub const Material = opaque{
        pub fn create(context: *Context) OvrAudioError!*Material {
            var result: ?*Material = null;
            const rc = raw_geometry.ovrAudio_CreateAudioMaterial(context, &result);
            if (rc == Success and result != null) return result.?;
            return decodeError(rc);
        }

        pub fn destroy(self: *Material) void {
            const rc = raw_geometry.ovrAudio_DestroyAudioMaterial(self);
            safe_assert(rc == Success);
        }

        pub fn setFrequency(self: *Material, property: MaterialProperty, frequency: f32, value: f32) OvrAudioError!void {
            const rc = raw_geometry.ovrAudio_AudioMaterialSetFrequency(self, property, frequency, value);
            if (rc == Success) return;
            return decodeError(rc);
        }

        pub fn getFrequency(self: *Material, property: MaterialProperty, frequency: f32) OvrAudioError!f32 {
            var res: f32 = 0;
            const rc = raw_geometry.ovrAudio_AudioMaterialGetFrequency(self, property, frequency, &res);
            if (rc == Success) return res;
            return decodeError(rc);
        }

        pub fn reset(self: *Material, property: MaterialProperty) OvrAudioError!void {
            const rc = raw_geometry.ovrAudio_AudioMaterialReset(self, property);
            if (rc == Success) return;
            return decodeError(rc);
        }
    };

    /// \brief A handle to geometry that sound interacts with. 0/NULL/nullptr represent an invalid handle. */
    pub const Geometry = opaque{
        pub fn create(context: *Context) OvrAudioError!*Geometry {
            var res: ?*Geometry = null;
            const rc = raw_geometry.ovrAudio_CreateAudioGeometry(context, &res);
            if (rc == Success and res != null) return res.?;
            return decodeError(rc);
        }

        pub fn destroy(self: *Geometry) void {
            const rc = raw_geometry.ovrAudio_DestroyAudioGeometry(self);
            safe_assert(rc == Success);
        }

        pub fn uploadMesh(self: *Geometry, mesh: Mesh) OvrAudioError!void {
            const rc = raw_geometry.ovrAudio_AudioGeometryUploadMesh(self, &mesh);
            if (rc == Success) return;
            return decodeError(rc);
        }

        pub fn uploadMeshArrays(
            self: *Geometry,
            vertices: *const anyopaque,
            vertices_byte_offset: usize,
            vertex_count: usize,
            vertex_stride: usize,
            vertex_type: ScalarType,
            indices: *const anyopaque,
            indices_byte_offset: usize,
            index_count: usize,
            index_type: ScalarType,
            groups: []const MeshGroup,
        ) OvrAudioError!void {
            const rc = raw_geometry.ovrAudio_AudioGeometryUploadMeshArrays(
                self,
                vertices,
                vertices_byte_offset,
                vertex_count,
                vertex_stride,
                vertex_type,
                indices,
                indices_byte_offset,
                index_count,
                index_type,
                groups.ptr,
                groups.len,
            );
            if (rc == Success) return;
            return decodeError(rc);
        }

        pub fn setTransform(self: *Geometry, matrix4x4: *const [16]f32) OvrAudioError!void {
            const rc = raw_geometry.ovrAudio_AudioGeometrySetTransform(self, matrix4x4);
            if (rc == Success) return;
            return decodeError(rc);
        }
        pub fn getTransform(self: *Geometry) ![16]f32 {
            var res: [16]f32 = undefined;
            const rc = raw_geometry.ovrAudio_AudioGeometryGetTransform(self, &res);
            if (rc == Success) return res;
            return decodeError(rc);
        }

        pub fn writeMeshFile(self: *Geometry, file_path: [*:0]const u8) OvrAudioError!void {
            const rc = raw_geometry.ovrAudio_AudioGeometryWriteMeshFile(self, file_path);
            if (rc == Success) return;
            return decodeError(rc);
        }
        pub fn readMeshFile(self: *Geometry, file_path: [*:0]const u8) OvrAudioError!void {
            const rc = raw_geometry.ovrAudio_AudioGeometryReadMeshFile(self, file_path);
            if (rc == Success) return;
            return decodeError(rc);
        }
        pub fn writeMeshFileObj(self: *Geometry, file_path: [*:0]const u8) OvrAudioError!void {
            const rc = raw_geometry.ovrAudio_AudioGeometryWriteMeshFileObj(self, file_path);
            if (rc == Success) return;
            return decodeError(rc);
        }

        pub fn writeMeshData(self: *Geometry, serializer: Serializer) OvrAudioError!void {
            const rc = raw_geometry.ovrAudio_AudioGeometryWriteMeshData(self, &serializer);
            if (rc == Success) return;
            return decodeError(rc);
        }
        pub fn readMeshData(self: *Geometry, serializer: Serializer) OvrAudioError!void {
            const rc = raw_geometry.ovrAudio_AudioGeometryReadMeshData(self, &serializer);
            if (rc == Success) return;
            return decodeError(rc);
        }
    };

    pub const context_funcs = struct {
        pub fn createMaterial(self: *Context) OvrAudioError!*Material {
            return Material.create(self);
        }

        pub fn createGeometry(self: *Context) OvrAudioError!*Geometry {
            return Geometry.create(self);
        }

        pub fn setPropagationQuality(self: *Context, quality: f32) OvrAudioError!void {
            const rc = raw_geometry.ovrAudio_SetPropagationQuality(self, quality);
            if (rc == Success) return;
            return decodeError(rc);
        }

        pub fn setPropagationThreadAffinity(self: *Context, cpu_mask: u64) OvrAudioError!void {
            const rc = raw_geometry.ovrAudio_SetPropagationThreadAffinity(self, cpu_mask);
            if (rc == Success) return;
            return decodeError(rc);
        }
    };

    /// \brief An enumeration of the scalar types supported for geometry data. */
    pub const ScalarType = enum (u32) {
        int8,
        uint8,
        int16,
        uint16,
        int32,
        uint32,
        int64,
        uint64,
        float16,
        float32,
        float64,
        _,
    };

    /// \brief The type of mesh face that is used to define geometry.
    ///
    /// For all face types, the vertices should be provided such that they are in counter-clockwise
    /// order when the face is viewed from the front. The vertex order is used to determine the
    /// surface normal orientation.
    pub const FaceType = enum (u32) {
        /// \brief A face type that is defined by 3 vertex indices. */
        triangles = 0,
        /// \brief A face type that is defined by 4 vertex indices. The vertices are assumed to be coplanar. */
        quads = 1,
        _,
    };

    /// \brief The properties for audio materials. All properties are frequency dependent. */
    pub const MaterialProperty = enum (u32) {
        /// \brief The fraction of sound arriving at a surface that is absorbed by the material.
        ///
        /// This value is in the range 0 to 1, where 0 indicates a perfectly reflective material, and
        /// 1 indicates a perfectly absorptive material. Absorption is inversely related to the reverberation time,
        /// and has the strongest impact on the acoustics of an environment. The default absorption is 0.1.
        absorption = 0,
        /// \brief The fraction of sound arriving at a surface that is transmitted through the material.
        ///
        /// This value is in the range 0 to 1, where 0 indicates a material that is acoustically opaque,
        /// and 1 indicates a material that is acoustically transparent.
        /// To preserve energy in the simulation, the following condition must hold: (1 - absorption + transmission) <= 1
        /// If this condition is not met, the transmission and absorption coefficients will be modified to
        /// enforce energy conservation. The default transmission is 0.
        transmission = 1,
        /// \brief The fraction of sound arriving at a surface that is scattered.
        ///
        /// This property in the range 0 to 1 controls how diffuse the reflections are from a surface,
        /// where 0 indicates a perfectly specular reflection and 1 indicates a perfectly diffuse reflection.
        /// The default scattering is 0.5.
        scattering = 2,
        _,
    };

    /// \brief A struct that is used to provide the vertex data for a mesh. */
    pub const MeshVertices = packed struct {
        /// \brief A pointer to a buffer of vertex data with the format described in this structure. This cannot be null. */
        vertices: *const anyopaque align(1),
        /// \brief The offset in bytes of the 0th vertex within the buffer. */
        byte_offset: usize align(1),
        /// \brief The number of vertices that are contained in the buffer. */
        vertex_count: usize align(1),
        /// \brief If non-zero, the stride in bytes between consecutive vertices. */
        vertex_stride: usize align(1),
        /// \brief The primitive type of vertex coordinates. Each vertex is defined by 3 consecutive values of this type. */
        vertex_type: ScalarType align(1),
    };

    /// \brief A struct that is used to provide the index data for a mesh. */
    pub const MeshIndices = packed struct {
        /// \brief A pointer to a buffer of index data with the format described in this structure. This cannot be null. */
        indices: *const anyopaque align(1),
        /// \brief The offset in bytes of the 0th index within the buffer. */
        byte_offset: usize align(1),
        /// \brief The total number of indices that are contained in the buffer. */
        index_count: usize align(1),
        /// \brief The primitive type of the indices in the buffer. This must be an integer type. */
        index_type: ScalarType align(1),
    };

    /// \brief A struct that defines a grouping of mesh faces and the material that should be applied to the faces. */
    pub const MeshGroup = packed struct {
        /// \brief The offset in the index buffer of the first index in the group. */
        index_offset: usize align(1),
        /// \brief The number of faces that this group uses from the index buffer.
        ///
        /// The number of bytes read from the index buffer for the group is determined by the formula: (faceCount)*(verticesPerFace)*(bytesPerIndex)
        face_count: usize align(1),
        /// \brief The type of face that the group uses. This determines how many indices are needed to define a face. */
        face_type: FaceType align(1),
        /// \brief A handle to the material that should be assigned to the group. If equal to null, a default material is used instead. */
        material: ?*Material align(1),
    };

    /// \brief A struct that completely defines an audio mesh. */
    pub const Mesh = packed struct {
        /// \brief The vertices that the mesh uses. */
        vertices: MeshVertices,
        /// \brief The indices that the mesh uses. */
        indices: MeshIndices,
        /// \brief A pointer to an array of ovrAudioMeshGroup that define the material groups in the mesh.
        ///
        /// The size of the array must be at least groupCount. This cannot be null.
        groups: ?[*]const MeshGroup align(1),
        /// \brief The number of groups that are part of the mesh. */
        group_count: usize align(1),

        comptime {
            if (@alignOf(Mesh) != 1) @compileError("ovr_audio.Mesh has incorrect alignment!");
        }
    };

    /// \brief A structure that contains function pointers to reading/writing data to an arbitrary source/sink. */
    const Serializer = packed struct {
        /// \brief A function pointer that reads bytes from an arbitrary source. This pointer may be null if only writing is required. */
        read: ?ReadCallback align(1) = null,
        /// \brief A function pointer that writes bytes to an arbitrary destination. This pointer may be null if only reading is required. */
        write: ?WriteCallback align(1) = null,
        /// \brief A function pointer that seeks within the data stream. This pointer may be null if seeking is not supported. */
        seek: ?SeekCallback align(1) = null,
        /// \brief A pointer to user-defined data that will be passed in as the first argument to the serialization functions. */
        user_data: ?*anyopaque align(1) = null,

        /// \brief A function pointer that reads bytes from an arbitrary source and places them into the output byte array.
        ///
        /// The function should return the number of bytes that were successfully read, or 0 if there was an error.
        pub const ReadCallback = fn (user_data: ?*anyopaque, out_bytes: [*]u8, byte_count: usize) callconv(.C) usize;
        /// \brief A function pointer that writes bytes to an arbitrary destination.
        ///
        /// The function should return the number of bytes that were successfully written, or 0 if there was an error.
        pub const WriteCallback = fn (user_data: ?*anyopaque, bytes: [*]const u8, byte_count: usize) callconv(.C) usize;
        /// \brief A function pointer that seeks within the data stream.
        ///
        /// The function should seek by the specified signed offset relative to the current stream position.
        /// The function should return the actual change in stream position. Return 0 if there is an error or seeking is not supported.
        pub const SeekCallback = fn (user_data: ?*anyopaque, seek_offset: i64) callconv(.C) i64;
    };

    // This is exposed publicly as ovr.audio.raw.geometry
    const raw_geometry = struct {
        pub extern fn ovrAudio_SetPropagationQuality(context: *Context, quality: f32) callconv(.C) Result;
        pub extern fn ovrAudio_SetPropagationThreadAffinity(context: *Context, cpu_mask: u64) callconv(.C) Result;
        pub extern fn ovrAudio_CreateAudioGeometry(context: *Context, out_geometry: *?*Geometry) callconv(.C) Result;
        pub extern fn ovrAudio_DestroyAudioGeometry(geometry: *Geometry) callconv(.C) Result;

        pub extern fn ovrAudio_AudioGeometryUploadMesh(
            geometry: *Geometry,
            mesh: *const Mesh,
            // simplification: *const MeshSimplificationParameters,
        ) callconv(.C) Result;
        pub extern fn ovrAudio_AudioGeometryUploadMeshArrays(
            geometry: *Geometry,
            vertices: ?*const anyopaque,
            vertices_byte_offset: usize,
            vertex_count: usize,
            vertex_stride: usize,
            vertex_type: ScalarType,
            indices: ?*const anyopaque,
            indices_byte_offset: usize,
            index_count: usize,
            index_type: ScalarType,
            groups: ?[*]const MeshGroup,
            group_count: usize,
            // simplification: *const MeshSimplificationParameters,
        ) callconv(.C) Result;

        pub extern fn ovrAudio_AudioGeometrySetTransform(geometry: *Geometry, matrix4x4: *const [16]f32) callconv(.C) Result;
        pub extern fn ovrAudio_AudioGeometryGetTransform(geometry: *Geometry, matrix4x4: *[16]f32) callconv(.C) Result;

        pub extern fn ovrAudio_AudioGeometryWriteMeshFile(geometry: *Geometry, file_path: [*:0]const u8) callconv(.C) Result;
        pub extern fn ovrAudio_AudioGeometryReadMeshFile(geometry: *Geometry, file_path: [*:0]const u8) callconv(.C) Result;
        pub extern fn ovrAudio_AudioGeometryWriteMeshFileObj(geometry: *Geometry, file_path: [*:0]const u8) callconv(.C) Result;

        pub extern fn ovrAudio_CreateAudioMaterial(context: *Context, out_material: *?*Material) callconv(.C) Result;
        pub extern fn ovrAudio_DestroyAudioMaterial(material: *Material) callconv(.C) Result;
        pub extern fn ovrAudio_AudioMaterialSetFrequency(material: *Material, property: MaterialProperty, frequency: f32, value: f32) callconv(.C) Result;
        pub extern fn ovrAudio_AudioMaterialGetFrequency(material: *Material, property: MaterialProperty, frequency: f32, out_value: *f32) callconv(.C) Result;
        pub extern fn ovrAudio_AudioMaterialReset(material: *Material, property: MaterialProperty) callconv(.C) Result;

        pub extern fn ovrAudio_AudioGeometryWriteMeshData(geometry: *Geometry, serializer: *const Serializer) callconv(.C) Result;
        pub extern fn ovrAudio_AudioGeometryReadMeshData(geometry: *Geometry, serializer: *const Serializer) callconv(.C) Result;
    };
};

test {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(Context);
    std.testing.refAllDecls(raw);
    std.testing.refAllDecls(geometry);
    std.testing.refAllDecls(geometry.raw_geometry);
    std.testing.refAllDecls(geometry.Material);
    std.testing.refAllDecls(geometry.Geometry);
    std.testing.refAllDecls(geometry.context_funcs);
}

test "reflection bands" {
    const bands = MaterialPreset.Grass.getReflectionBands();
    try std.testing.expectEqualSlices(f32, &Bands{ 0.881126285, 0.507170796, 0.131893098 , 0.0103688836 }, &bands);
}
