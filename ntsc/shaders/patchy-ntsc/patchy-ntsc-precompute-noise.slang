#version 450

/*
Patchy NTSC
Copyright (C) 2024 Patchy68k/PlainOldPants

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>. 

*/

// This shader runs BEFORE EVERYTHING ELSE and generates convincing-looking noise, with four samples per pixel.

#pragma name GenerateNoise

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    vec4 FinalViewportSize;
} params;

// Includes constants, global, and all parameters
#include "patchy-ntsc-inc-params.inc"

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

// Includes lowpass and bandpass functions.
// Using DONT_DO_SIGNAL_RES sets SIGNAL_RES to 1, which is
// important because we're still dealing with the console's
// raw pixels, not samples of the video signal.
#define DONT_DO_SIGNAL_RES
#include "patchy-ntsc-inc-filters.inc"

#define euler 2.7182818284

vec4 getNoise() {
    // Compensate for cropped overscan, assuming equal crop on both sides.
    // Current position in pixels, both x and y being decimal numbers.
    
    vec2 pixelCoord = realPixelCoord();
    vec4 offsets = vec4(0, 0.25, 0.5, 0.75);
    vec4 realOffX = (vec4(pixelCoord.x) + offsets) / getSizes().x;
    vec4 noise = vec4(0.0);
    
    // Add RF noise
    // 256 / 341.25 comes from the comments in NTSC-CRT (by EMMIR) about its SNES signal emulation.
    // 256 is the number of game pixels per scanline, while 341.25 is the duration of a line of the video signal.
    // It's a close match to the NES's exactly 341 PPU pixels per line, as stated on the nesdev wiki.
    vec4 offsetXPart = realOffX * ccpre_scanline_dur / global.pn_total_scanline_dur;
    int offsetYPart = int(pixelCoord.y + 0.5);
    int offsetFramePart = int(params.FrameCount + 0.5);
    vec4 offsetFull = offsetXPart + vec4(offsetYPart + ccpre_num_lines * offsetFramePart);
    
    // https://en.wikipedia.org/wiki/Linear_congruential_generator
    const uint modulus = 0x7fffffff; // Use & instead of % for better performance
    const uint multiplier = 48271;
    const uint increment = 0;
    const uint truncation = 8;
    uint waveRng = int(global.pn_noise_rand_offset / 1000.0 * modulus + 0.5);
    uint heightRng = (int(pixelCoord.x * SIGNAL_RES + pixelCoord.y * params.OutputSize.x + 0.5) + params.FrameCount * int(ccpre_num_lines * params.OutputSize.x + 0.5)) & modulus;
#define RNG(rngName) (((rngName = (rngName * multiplier + increment) & modulus) >> truncation) / float(modulus >> truncation))

    float maxRate = pow(euler, global.pn_noise_base_rate);
    float minRate = global.pn_noise_lower_rate * maxRate / 10;

    for(int i = 0; i < int(global.pn_noise_counter + 0.5); i++) {
        float rate = RNG(waveRng) * (maxRate - minRate) + minRate;
        
        // WRONG way to do this part. If you do this, the float that we pass into the sin() function will get very big, and our noise will start disappearing over time and suddenly reappearing in a 1000-frame cycle.
//        noise += (randoms[(i * 2 + randOffset) % 1000] * (1.0 - minAmp) + minAmp) * sin(offsetFull * rate);
        
        // New way to avoid getting too large of a number in the sin() function.
        float overAmt = rate - floor(rate / (2 * pi)) * 2 * pi;
//        float overAmt = rate;
        float overAmtFrame = overAmt * ccpre_num_lines - floor(overAmt * (ccpre_num_lines / (2 * pi))) * (2 * pi);
//        float overAmtFrame = overAmt * ccpre_num_lines;
        
        noise += (global.pn_noise_mode > 3.5 ? RNG(heightRng) * rate / 200000 : global.pn_noise_mode > 2.5 ? pow(2, rate / 227.5) / 20000 : global.pn_noise_mode > 1.5 ? rate / 400000 : global.pn_noise_mode > 0.5 ? 1.0 / rate * 2 : 1.0 / global.pn_noise_counter)
                        * sin(offsetXPart * rate + vec4(offsetYPart * overAmt + offsetFramePart * overAmtFrame)) * global.pn_noise_severity;
    }
    
#undef RNG
    
    return noise;
}

void main()
{
    FragColor = getNoise();
}

