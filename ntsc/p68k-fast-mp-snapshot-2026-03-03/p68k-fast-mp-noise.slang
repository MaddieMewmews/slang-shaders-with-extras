#version 450

/*

Patchy68k Fast Multipass - Simulation of analog video signal artifacts and color correction
Copyright (C) 2025 Patchy68k/PlainOldPants

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>. 

*/

/*

This pass adds a fake RF noise effect.
It is very slow and inefficient.

*/

#pragma name PfmNoisePass

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    vec4 FinalViewportSize;

    float pfm_enableNoise;
    float noiseLo, noiseLo2, noiseHi, noiseHi2, noise3;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
    float 
          pn_noise_rand_offset,
//          pn_noise_min_rate,
//          pn_noise_max_rate,
          //pn_noise_base_rate,
          //pn_noise_lower_rate,
          //pn_noise_mode,
          pn_noise_channel,
          pn_noise_rate_by_channel,
          pn_noise_min_mhz,
          pn_noise_max_mhz,
          pn_noise_counter,
          pn_noise_severity;

} global;

#pragma parameter pfm_enableNoise "Enable noise" 1 0 1 1
#pragma parameter pn_noise_rand_offset "Noise random seed" 611 0 999 1
#pragma parameter pn_noise_severity "Noise overall severity factor" 0.3 0.0 20.0 0.025
#pragma parameter pn_noise_counter "Amount of sine waves (higher is better but needs more power)" 20 1 10000 1
//#pragma parameter pn_noise_mode "Noise adjustment mode" 2 0 3 1
//#pragma parameter pn_noise_channel "TV channel (USA): Off | 3 | 4 | Blah" 1 0 3 1
//#pragma parameter pn_noise_rate_by_channel "Channel preset noise rates" 1 0 1 1
//#pragma parameter pn_noise_min_mhz "(If channel isn't Off & Not using preset) Noise min MHz" 60 0 200 1
//#pragma parameter pn_noise_max_mhz "(If channel isn't Off & Not using preset) Noise max MHz" 72 0 200 1

#pragma parameter noiseLo "First noise parameter" 16 0 200 0.1
#pragma parameter noiseLo2 "First noise parameter precise control" 0.0 -10 10 0.01
//#pragma parameter noiseHi "Second noise parameter" 110 0 1000 0.1
#pragma parameter noise3 "Second noise parameter" 2.5 0 5 0.1
#pragma parameter noiseHi2 "Third noise parameter" 15 0 100 0.1

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
// #define DONT_DO_SIGNAL_RES
// #include "patchy-ntsc-inc-filters.inc"

// #define CC_PRESET_COND(setting, phase1, phase2, phase3) \
//     (global.pn_color_carrier_preset < 0.5 ? setting : \
//     global.pn_color_carrier_preset < 1.5 ? phase1 : \
//     global.pn_color_carrier_preset < 2.5 ? phase2 : \
//     phase3)
#define CC_PRESET_COND(setting, phase1, phase2, phase3) phase3
#define ccpre_scanline_dur CC_PRESET_COND(global.pn_scanline_dur, 320.0 * 8 / 15 / 3.5795454, 320.0 * 8 / 15 / 3.5795454, 256.0 / 1.5 / 3.5795454)
#define ccpre_total_scanline_dur CC_PRESET_COND(global.pn_total_scanline_dur, 63.55, 63.55, 341 / 1.5 / 3.5795454)
#define ccpre_num_lines CC_PRESET_COND(global.pn_num_lines, 262, 262, 262)
#define ccpre_color_amplitude CC_PRESET_COND(global.pn_color_amplitude, 1.0, 1.0, 1.0)
#define ccpre_color_freq CC_PRESET_COND(global.pn_color_freq, 3.5795454, 3.5795454, 3.5795454)
#define ccpre_color_init_offset CC_PRESET_COND(global.pn_color_init_offset, 0.7, 0.0, 0.0)
#define ccpre_color_line_offset CC_PRESET_COND(global.pn_color_line_offset, 0, 0.5, 1.0/3.0)
#define ccpre_color_screen_offset CC_PRESET_COND(global.pn_color_screen_offset, 0, 0.5, 1.0/3.0)
#define ccpre_color_screen_offset_modulo CC_PRESET_COND(global.pn_color_screen_offset_modulo, 2, 2, 2)

#define pi 3.14159265358
#define euler 2.7182818284

// If global.pn_signal_res > 0.5: Get the cropped and uncropped sizes of the screen, taking into account the possibility that the resolution was multiplied by an exact integer.
// If global.pn_signal_res < 0.5: Get the cropped and uncropped sizes of the screen, taking the dynamically set SIGNAL_RES into account.
vec4 getSizes() {
    // vec2 sizeUncropped = vec2(global.pn_width_uncropped, global.pn_height_uncropped);
    // vec2 sizeCropped = params.OutputSize.xy / vec2(SIGNAL_RES, 1);
    // 
    // if(global.pn_signal_res > 0.5) {
        // // Correct for integer-scaled resolutions.
        // if(global.pn_width_integer_mul > 0.5)
        //     sizeUncropped.x *= floor(0.501 + sizeCropped.x / sizeUncropped.x);
        // if(global.pn_height_integer_mul > 0.5)
        //     sizeUncropped.y *= floor(0.501 + sizeCropped.y / sizeUncropped.y);
        
        // if(global.pn_dual_width_mode > 0.5) {
        //     float smallWidthUncropped = global.pn_width_secondary_uncropped;
            
        //     // Correct for integer-scaled resolutions.
        //     if(global.pn_width_integer_mul > 0.5)
        //         smallWidthUncropped *= floor(0.501 + sizeCropped.x / smallWidthUncropped);
            
        //     // Use whichever resolution we're closer to, using the absolute value of the difference.
        //     float smallDiff = abs(sizeCropped.x - smallWidthUncropped);
        //     float largeDiff = abs(sizeCropped.x - sizeUncropped.x);
        //     if(smallDiff < largeDiff)
        //         sizeUncropped.x = smallWidthUncropped;
        // }
    // }
    
    return vec4(params.OriginalSize.xy, params.OutputSize.xy);
}

// Find which scanline we're on, and what percent of the active area has been completed.
// This takes cropped overscan and changed resolution into account, under three assumptions:
//      1. An equal amount of overscan was cropped on the left and right sides.
//      2. The top and bottom sides either had an equal amount cropped or had exactly one more pixel cropped off the bottom than on the top.
//      3. The resulution, horizontal or vertical, might have been multiplied by an exact integer. (For example, in bsnes-mercury.)
vec2 realPixelCoord() {
    vec4 sizes = getSizes();
    vec2 sizeUncropped = sizes.xy;
    vec2 sizeCropped = sizes.zw;
    vec2 pixelCoord = vTexCoord * sizeCropped + (sizeUncropped - sizeCropped) / 2.0;
    pixelCoord.y = floor(pixelCoord.y + 0.01);
    return pixelCoord;
}

vec4 getNoise() {
    // Compensate for cropped overscan, assuming equal crop on both sides.
    // Current position in pixels, both x and y being decimal numbers.
    
#define OFFSETS_MULTIPLIER 1
    vec2 pixelCoord = realPixelCoord();
    pixelCoord.y = floor(pixelCoord.y + 0.01);
    vec4 offsets[OFFSETS_MULTIPLIER];
    for(int i = 0; i < OFFSETS_MULTIPLIER << 2; i++) {
        offsets[i >> 2][i & 3] = i / float(OFFSETS_MULTIPLIER << 2);
    }
    vec4 realOffX[OFFSETS_MULTIPLIER];
    for(int i = 0; i < OFFSETS_MULTIPLIER; i++) {
        realOffX[i] = (vec4(pixelCoord.x) + offsets[i]) / getSizes().x;
    }
    vec4 noise[OFFSETS_MULTIPLIER];
    for(int i = 0; i < OFFSETS_MULTIPLIER; i++) {
        noise[i] = vec4(0);
    }
    
    // Add RF noise
    // 256 / 341.25 comes from the comments in NTSC-CRT (by EMMIR) about its SNES signal emulation.
    // 256 is the number of game pixels per scanline, while 341.25 is the duration of a line of the video signal.
    // It's a close match to the NES's exactly 341 PPU pixels per line, as stated on the nesdev wiki.
    vec4 offsetXPart[OFFSETS_MULTIPLIER];
    for(int i = 0; i < OFFSETS_MULTIPLIER; i++) {
        offsetXPart[i] = realOffX[i] * ccpre_scanline_dur / ccpre_total_scanline_dur;
    }
    int offsetYPart = int(pixelCoord.y + 0.5);
    int offsetFramePart = int(params.FrameCount + 3600 * 3 + 0.5); // The pattern is more predictable early on than later.
    vec4 offsetFull[OFFSETS_MULTIPLIER];
    for(int i = 0; i < OFFSETS_MULTIPLIER; i++) {
        offsetFull[i] = offsetXPart[i] + vec4(offsetYPart + ccpre_num_lines * offsetFramePart);
    }
    
    // https://en.wikipedia.org/wiki/Linear_congruential_generator
    const uint modulus = 0x7fffffff; // Use & instead of % for better performance
    const uint multiplier = 48271;
    const uint increment = 0;
    const uint truncation = 8;
    uint waveRng = int(global.pn_noise_rand_offset / 1000.0 * modulus + 0.5);
    //uint heightRng = (int(pixelCoord.x * SIGNAL_RES + pixelCoord.y * params.OutputSize.x + 0.5) + params.FrameCount * int(ccpre_num_lines * params.OutputSize.x + 0.5)) & modulus;
#define RNG(rngName) (((rngName = (rngName * multiplier + increment) & modulus) >> truncation) / float(modulus >> truncation))

    float maxRate;// = pow(euler, global.pn_noise_base_rate);
    float minRate;// = global.pn_noise_lower_rate * maxRate / 10;
    
    vec4 channelSine[OFFSETS_MULTIPLIER];
    for(int i = 0; i < OFFSETS_MULTIPLIER; i++) {
        channelSine[i] = vec4(1);
    }
    
//     if(global.pn_noise_channel > 0.5 && global.pn_noise_channel < 2.5) {
//         // https://en.wikipedia.org/wiki/Television_channel_frequencies as of 2024-10-31
//         float rate = (global.pn_noise_channel < 1.5 ? 61.25 : 67.25) * ccpre_total_scanline_dur * 2 * pi;
//         float overAmt = rate - floor(rate / (2 * pi)) * 2 * pi;
//         float overAmtFrame = overAmt * ccpre_num_lines - floor(overAmt * (ccpre_num_lines / (2 * pi))) * (2 * pi);
        
//         for(int i = 0; i < OFFSETS_MULTIPLIER; i++) {
//             channelSine[i] = sin(offsetXPart[i] * rate + vec4(offsetYPart * overAmt + offsetFramePart * overAmtFrame)) * 2;
// //            channelSine[i] *= channelSine[i];
//         }
// //        minRate = ccpre_total_scanline_dur * 2 * pi * 0.5;
// //        maxRate = ccpre_total_scanline_dur * 2 * pi * 5.5;
//         if(global.pn_noise_rate_by_channel > 0.5) {
//             // Numbers determined experimentally, based on what ranges did/didn't appear in the resulting signal
//             minRate = ccpre_total_scanline_dur * 2 * pi * (global.pn_noise_channel < 1.5 ? 48 : 54);
//             maxRate = ccpre_total_scanline_dur * 2 * pi * (global.pn_noise_channel < 1.5 ? 72 : 78);
//         } else {
//             minRate = ccpre_total_scanline_dur * 2 * pi * global.pn_noise_min_mhz;
//             maxRate = ccpre_total_scanline_dur * 2 * pi * global.pn_noise_max_mhz;
//         }
//     } else if(global.pn_noise_channel > 2.5) {
        minRate = ccpre_total_scanline_dur * 2 * pi * pow(0.1, params.noiseLo - 10 + params.noiseLo2 / 10 - (params.noise3) / 10);
        maxRate = ccpre_total_scanline_dur * 2 * pi * pow(0.1, params.noiseLo - 10 + params.noiseLo2 / 10 + (params.noise3) / 10);
        float minRate2 = ccpre_total_scanline_dur * 2 * pi * (/*params.noiseHi*/110 - params.noiseHi2 / 100000);
        float maxRate2 = ccpre_total_scanline_dur * 2 * pi * (/*params.noiseHi*/110 + params.noiseHi2 / 100000);
    // }

    for(int i = 0; i < int(global.pn_noise_counter + 0.5); i++) {
        float rate = RNG(waveRng) * (maxRate - minRate) + minRate;
        float phase = RNG(waveRng) * 2 * pi;
        // WRONG way to do this part. If you do this, the float that we pass into the sin() function will get very big, and our noise will start disappearing over time and suddenly reappearing in a 1000-frame cycle.
//        noise += (randoms[(i * 2 + randOffset) % 1000] * (1.0 - minAmp) + minAmp) * sin(offsetFull * rate);
        
        // New way to avoid getting too large of a number in the sin() function.
        float overAmt = rate - floor(rate / (2 * pi)) * 2 * pi;
//        float overAmt = rate;
        float overAmtFrame = overAmt * ccpre_num_lines - floor(overAmt * (ccpre_num_lines / (2 * pi))) * (2 * pi);
//        float overAmtFrame = overAmt * ccpre_num_lines;

        float rate2 = RNG(waveRng) * (maxRate2 - minRate2) + minRate2;
        float phase2 = RNG(waveRng) * 2 * pi;
        float overAmt2 = rate2 - floor(rate2 / (2 * pi)) * 2 * pi;
        float overAmtFrame2 = overAmt2 * ccpre_num_lines - floor(overAmt2 * (ccpre_num_lines / (2 * pi))) * (2 * pi);
        
        
//        vec4 offsetShrunken;
        for(int j = 0; j < OFFSETS_MULTIPLIER; j++) {
            // noise[j] += global.pn_noise_severity / OFFSETS_MULTIPLIER / global.pn_noise_counter * channelSine[j] * sin(phase + offsetXPart[j] * rate + vec4(offsetYPart * overAmt + offsetFramePart * overAmtFrame));
            noise[j] += global.pn_noise_severity / OFFSETS_MULTIPLIER / global.pn_noise_counter * channelSine[j]
                * sin((phase + offsetXPart[j] * rate + vec4(offsetYPart * overAmt + offsetFramePart * overAmtFrame))
                    * (sin(phase2 + offsetXPart[j] * rate2 + vec4(offsetYPart * overAmt2 + offsetFramePart * overAmtFrame2)))
                );
        }
        
//        float noisy += (global.pn_noise_mode > 3.5 ? RNG(heightRng) * rate / 200000 : global.pn_noise_mode > 2.5 ? pow(2, rate / 227.5) / 20000 : global.pn_noise_mode > 1.5 ? rate / 400000 : global.pn_noise_mode > 0.5 ? 1.0 / rate * 2 : 1.0 / global.pn_noise_counter)
//                        * global.pn_noise_severity;
    }
    
#undef RNG
//    return noise[0];
    vec4 retu = vec4(0);
    for(int i = 0; i < OFFSETS_MULTIPLIER << 2; i++) {
        retu[i / OFFSETS_MULTIPLIER] += noise[i >> 2][i & 3];
    }
//    return vec4(0);
    return retu;
    
    return vec4(0);
}

void main()
{
    if(params.pfm_enableNoise < 0.5) {
        FragColor = texture(Source, vTexCoord);
    } else {
        FragColor = texture(Source, vTexCoord) + getNoise();
    }
}

