#version 450

/*

Patchy68k Fast Multipass - Simulation of analog video signal artifacts and color correction
Copyright (C) 2025 Patchy68k/PlainOldPants

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>. 

*/

/*

https://pub.smpte.org/doc/st170/20041130-pub/st0170-2004_stable2010.pdf
SMPTE 170M-2004 - Composite Analog Video Signal - NTSC for Studio Applications

This pass low-passes the signal under 4.2 MHz.

When putting this in a shader preset, use the following settings:

Input must use nearest-neighbor interpolation.
Input sizes should be the same as the output sizes.
Framebuffer should use floating point, not integers.

*/

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;

    float //pfm_rfLowpass,
          pfm_ccWantRes,
          pfm_ccNum,
          pfm_ccDenom;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma parameter pfm_ccWantRes "Console default resolution in pixels (0=Don't care)" 0 0 10000 1
#pragma parameter pfm_ccNum "Color carrier wavelength numerator" 1 1 10000 1
#pragma parameter pfm_ccDenom "Color carrier wavelength denominator" 1 1 10000 1
//#pragma parameter pfm_rfLowpass "Skip RF lowpass (required to restore Color correctly)" 1 0 1 1

#define pi 3.14159265358

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main() {
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D PfmInputPass;

// Input is automatically multiplied by 2pi
float sinc(float val) {
    return val == 0 ? 1 : sin(2 * pi * val) / (2 * pi * val);
}

// Input is automatically multiplied by 2pi
vec4 sinc(vec4 val) {
    for(int i = 0; i < 4; i++) {
        val[i] = sinc(val[i]);
    }
    return val;
}

// Hamming window
vec4 window(vec4 offsets, float hammingSize) {
    const float a0 = 25.0 / 46.0;
    vec4 res;
    for(int i = 0; i < 4; i++) {
        res[i] = offsets[i] >= -0.5 && offsets[i] <= 0.5 ? a0 + (1 - a0) * cos(2 * pi * clamp(offsets[i] / hammingSize, -0.5, 0.5)) : 0;
    }
    return res;
}

// Hamming window * sinc function
vec4 windowSinc(vec4 offsets, float hammingSize, float sincRate) {
    return window(offsets, hammingSize) * sinc(offsets * sincRate);
}

// Hamming window * sinc function
vec4 windowSincNotch(vec4 offsets, float hammingSize, float sincRate, float notchFreq) {
    return window(offsets, hammingSize) * sinc(offsets * sincRate) * pow(cos(2 * pi * notchFreq * offsets), vec4(2.0));
}

void main() {

    //if(params.pfm_rfLowpass > 0.5) {
        FragColor = texture(Source, vTexCoord);
        return;
    //}

///////////////////////////
// Standard constants
///////////////////////////

    // "Size" means wavelength in microseconds.
    // "Rate" means frequency in megahertz.
    float ccStdSize = 1 / (5.0 * 63.0 / 88.0); // About 3.579545 MHz
    // RF lowpass rates.
    // SMPTE 170M-2004 doesn't include anything about this.
    // The 1953 NTSC specification does show a diagram where the signal is flat up to 4.2 MHz, and everything is gone by 4.5 MHz.
    // I set this up similarly to the baseband I filter, such that 4.2 MHz is less than 2 db down, and 4.5 MHz is at least 20 db down.
    float lowpassWindowRFSize = 2;
    float lowpassSincRFRate = 10;

///////////////////////////////////////
// Corrected constants
// Relative to input size
///////////////////////////////////////

    // There isn't a standard for the duration of the active area of the line.
    // I have chosen it such that the number of color carrier cycles per the active area is the same as in the NES and SNES.
    // On the NES and SNES, there are 256 pixels horizontally, and the color carrier is 1.5 pixels wide.
    // Assuming the standard frequency, that makes each line 47.678306816 microseconds long.
    float ccSize = params.pfm_ccWantRes < 0.5 ? 12.0 / (256.0 * 8.0) : params.pfm_ccNum / params.pfm_ccDenom / textureSize(PfmInputPass, 0).x * int(textureSize(PfmInputPass, 0).x / params.pfm_ccWantRes + 0.5);
    float hammingSize = lowpassWindowRFSize * ccSize / ccStdSize;
    float sincRate = lowpassSincRFRate / ccSize * ccStdSize;

    // Effective x-coordinates of the four samples within this shader fragment.
    vec4 subX = (vTexCoord.x * params.OutputSize.x + vec4(-3.0/8.0, -1.0/8.0, 1.0/8.0, 3.0/8.0)) * params.OutputSize.z;
    
    vec4 results = vec4(0);
    
    float minX = (int((subX[0] - hammingSize / 2.0) * params.SourceSize.x - 0.0001) + 0.5) * params.SourceSize.z;
    float maxX = (int((subX[3] + hammingSize / 2.0) * params.SourceSize.x + 0.0001) + 0.5) * params.SourceSize.z;
    vec4 sums = vec4(0);
    vec4 xSplit = vec4(-3.0/8.0, -1.0/8.0, 1.0/8.0, 3.0/8.0) * params.SourceSize.z;
    for(float offX = minX; offX < maxX + 0.0001; offX += params.SourceSize.z) {
        vec4 thisPixel = texture(Source, vec2(offX, vTexCoord.y));
        for(int i = 0; i < 4; i++) {
            vec4 firFilt = windowSinc(offX + xSplit[i] - subX, hammingSize, sincRate);
            sums += dot(firFilt, vec4(1.0));
            results += dot(firFilt, vec4(thisPixel[i]));
        }
    }
    results /= sums;

    FragColor = results;
    // FragColor = vec4(1);
}
