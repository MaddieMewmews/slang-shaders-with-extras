#version 450

/*
   SNES 2CHIP RGB output: S-PPU2 DAC settling (horizontal, per color channel)

   What this models
   ----------------
   On the first-generation consoles (discrete S-PPU1/S-PPU2, "2CHIP"), each color channel's output
   settles slowly when a pixel changes to an INTERMEDIATE level, and quickly when it changes to
   black or full level. Direction does not matter, the new level does.  The 1CHIP / Jr. consoles do
   not have this problem (their DAC was changed), so bypass this pass for those.

   Model: every pixel holds its 5-bit level for one pixel period T. During that time the channel
   voltage follows a first-order lag toward the level, with a time constant that depends on the level:

       tau(level) = tau_floor + (tau_mid - tau_floor) * 4 * level * (1 - level)

   so tau is smallest at 0 and 1 and largest at mid-scale. The lag is solved exactly (no per-pixel
   approximation), the history is carried across pixels, and the output is the average voltage over
   the output pixel's footprint. Channels are independent. Before the first pixel the DAC is at black.

   Sources and what is measured vs assumed
   ---------------------------------------
   MEASURED   Chris Covell's oscilloscope captures of an old SFC/SNES vs an SFC Jr.:
              https://www.chrismcovell.com/gotRGB/snesblur.html
                - to/from black or white per channel: sharp enough (slightly slower than the Jr.)
                - to an intermediate level: slow; black -> medium grey takes about 0.6 us
                - falls from full level to an intermediate level are similarly slow
                - each color component behaves independently
   REPORTED   The blur comes from the DACs inside S-PPU2, not the RGB encoder (lidnariq, nesdev forum
              topic 16052). The 1CHIP DAC is sharper (SNESdev wiki, Version differences).
   ASSUMED    (not measured, tune these)
                - "about 0.6 us" is read as the 10%-90% rise time, so tau_mid = 0.6 us / 2.197 = 273 ns.
                  If it meant full settling, tau_mid is closer to 130 ns.
                - tau_floor = 45 ns (Covell: slightly slower than the Jr., no number given).
                - the level dependence is a parabola, 0 at the ends and 1 at mid-scale. This is what an
                  unbuffered resistor-string DAC would give (output impedance peaks at mid-scale) and it
                  matches the qualitative captures; the exact shape was not measured.
                - rising and falling transitions are symmetric (snes_fall_scale = 1). Reports disagree:
                  lidnariq says fast rise / slow fall, one forum measurement says the opposite.
   NOT MODELED  vertical effects, the S-ENC / composite / S-Video encoder, the brightness (INIDISP) DAC,
                revision differences between 2CHIP boards, any overshoot (none documented).

   Use it as the FIRST pass, on the core's raw output (the 5-bit level is proportional to the DAC
   voltage, so do this before gamma or color correction), with nearest-neighbor input.
*/

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OutputSize;
    uint FrameCount;
    float snes_tau_mid;
    float snes_tau_floor;
    float snes_fall_scale;
    float snes_pixel_ns;
    float snes_line_pixels;
} params;

#pragma parameter snes_tau_mid "Mid-level settling time constant (ns)" 273.0 20.0 800.0 1.0
#pragma parameter snes_tau_floor "0/full-level settling time constant (ns)" 45.0 1.0 200.0 1.0
#pragma parameter snes_fall_scale "Falling transition time scale" 1.0 0.25 4.0 0.05
#pragma parameter snes_pixel_ns "Pixel period of a 256-pixel line (ns)" 186.2 150.0 220.0 0.1
#pragma parameter snes_line_pixels "Pixels per line the source width represents" 256.0 128.0 1024.0 1.0

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;

#define HISTORY_MAX 24

// Settling time constant (ns) for each channel, given the level its DAC is switching to.
vec3 tau_of(vec3 level)
{
    vec3 shape = 4.0 * level * (1.0 - level);   // 0 at black and full level, 1 at mid-scale
    return vec3(params.snes_tau_floor) + (params.snes_tau_mid - params.snes_tau_floor) * shape;
}

// Pixel x of this scanline. Before the first pixel the DAC sits at black (blanking).
vec3 fetch_px(int x, int y)
{
    if (x < 0)
        return vec3(0.0);
    x = min(x, int(params.SourceSize.x) - 1);
    return texelFetch(Source, ivec2(x, y), 0).rgb;
}

void main()
{
    // Time per source pixel. A 256-wide source is one pixel per dot clock; a 512-wide source is half that.
    float T = params.snes_pixel_ns * params.snes_line_pixels / params.SourceSize.x;

    float xs = vTexCoord.x * params.SourceSize.x;
    int ix = int(floor(xs));
    int iy = clamp(int(vTexCoord.y * params.SourceSize.y), 0, int(params.SourceSize.y) - 1);

    // How many earlier pixels still matter (about 5 time constants).
    float tau_max = max(params.snes_tau_mid, params.snes_tau_floor) * max(params.snes_fall_scale, 1.0);
    int n = int(clamp(ceil(5.0 * tau_max / T), 3.0, float(HISTORY_MAX)));

    // Voltage at the start of pixel ix, assuming the line was settled n pixels ago.
    vec3 v = fetch_px(ix - n, iy);
    for (int j = ix - n + 1; j < ix; j++)
    {
        vec3 c = fetch_px(j, iy);
        vec3 tau = tau_of(c);
        tau = mix(tau, tau * params.snes_fall_scale, vec3(lessThan(c, v)));
        v = c + (v - c) * exp(-T / tau);
    }

    // The current pixel: v(p) = c + (v - c) * exp(-p * T / tau), p in 0..1 across the pixel.
    vec3 c = fetch_px(ix, iy);
    vec3 tau = tau_of(c);
    tau = mix(tau, tau * params.snes_fall_scale, vec3(lessThan(c, v)));

    // Average over this output pixel's footprint inside the source pixel (the whole pixel at 1:1).
    float w = params.SourceSize.x / params.OutputSize.x;
    float f = xs - floor(xs);
    float p0 = clamp(f - 0.5 * w, 0.0, 1.0);
    float p1 = clamp(f + 0.5 * w, 0.0, 1.0);
    float dp = p1 - p0;

    vec3 result;
    if (dp > 1e-4)
        result = c + (v - c) * (tau / (T * dp)) * (exp(-p0 * T / tau) - exp(-p1 * T / tau));
    else
        result = c + (v - c) * exp(-p0 * T / tau);

    FragColor = vec4(result, 1.0);
}
