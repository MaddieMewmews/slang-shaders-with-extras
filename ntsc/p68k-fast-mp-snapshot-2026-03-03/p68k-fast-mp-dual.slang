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

This pass decodes a composite signal into uncorrected RGB, using appropriate FIR filters.

When putting this in a shader preset, use the following settings:

Framebuffer should use floating point, not integers.
Input must use nearest-neighbor interpolation.
Input and output resolutions must be unchanged from the previous pass.

*/

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;

    float pfm_demodType;
    float pfm_sharpness,
          pfm_alt_notch,
          pfm_offsetInit,
          pfm_offsetLine,
          pfm_offsetFrame,
          pfm_offsetFrameMod,
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
#pragma parameter pfm_offsetInit "Color initial offset" 0 0 1 0.01
#pragma parameter pfm_offsetLine "Color per-line offset" 2 -10 10 1
#pragma parameter pfm_offsetFrame "Color per-frame offset" 2 -10 10 1
#pragma parameter pfm_offsetFrameMod "Color per-frame modulus" 2 1 10 1
#pragma parameter pfm_demodType "Demod rates: 0: Narrowband 1: Baseband" 0 0 1 1
#pragma parameter pfm_sharpness "Sharpness" 0.461538462 0 1 0.038461538
#pragma parameter pfm_alt_notch "Y filter: 0:Notch 1:Lowpass" 0 0 1 1

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

///////////////////////////
// Standard constants
///////////////////////////

    // SMPTE 170M standard conversions from RGB to Y B-Y R-Y
    // Decoders never bothered with I/Q.
    mat3 rgbToYBmyRmy = mat3(
        0.299, -0.299, 0.701,
        0.587, -0.587, -0.587,
        0.114, 0.886, -0.114
    );
    mat3 YBmyRmyToRgb = inverse(rgbToYBmyRmy);
    // Decoders generally demodulated B-Y and R-Y at nonstandard offsets as part of a larger color correction.
    // That is not directly simulated here. Trying to directly implement that would cause some oddities.
    // Instead, we demodulate B-Y and R-Y according to the SMPTE 170M-2004 standard, and in the next pass, we correct that with a linear matrix.
    // Because of how the algebra works out, this only gives accurate results if we do identical FIR filters on both subcarriers.
    // Decoders generally did identical filters too, so this works.

    // "Size" means wavelength in microseconds.
    // "Rate" means frequency in megahertz.
    float ccStdSize = 1 / (5.0 * 63.0 / 88.0); // About 3.579545 MHz
    // At 0.4 MHz, less than 2 db down. At 0.5 MHz, less than 6 db down. At 0.6 MHz, at least 6 db down.
    float lowpassWindowStdNarrowSize = 5.34;
    float lowpassSincStdNarrowRate = 0.459;
    // At 1.3 MHz, less than 2 db down. At 3.6 MHz, at least 20 db down.
    float lowpassWindowStdBaseSize = 0.573;
    float lowpassSincStdBaseRate = 0.747;

    // There is no standard way to separate Y.
    // In fact, there is no standard for decoding anything at all.
    float notchHammings[] = {7.75, 6.23, 5.17, 4.4, 3.85, 3.47, 3.12, 2.84, 2.60, 2.38, 2.19, 2.08, 1.901, 1.82, 1.74, 1.61, 1.55, 1.50, 1.41, 1.33, 1.29, 1.25, 1.21, 1.17, 1.09, 1.05, 1.02};
    float notchHammingStdSize = notchHammings[int((1 - params.pfm_sharpness) * 26 + 0.5)];
    float notchSincStdRate = 1.0 / ccStdSize - (0.2 + 0.05 * (int((1 - params.pfm_sharpness) * 26 + 0.5)));
    float notchHammingStdSizeRatio = notchHammingStdSize / ccStdSize;
    float notchSincStdRateRatio = notchSincStdRate * ccStdSize;

///////////////////////////////////////
// Corrected constants
// Relative to input size
///////////////////////////////////////

    // There isn't a standard for the duration of the active area of the line.
    // I have chosen it such that the number of color carrier cycles per the active area is the same as in the NES and SNES.
    // On the NES and SNES, there are 256 pixels horizontally, and the color carrier is 1.5 pixels wide.
    // Assuming the standard frequency, that makes each line 47.678306816 microseconds long.
    float ccSize = params.pfm_ccWantRes < 0.5 ? 12.0 / (256.0 * 8.0) : params.pfm_ccNum / params.pfm_ccDenom / textureSize(PfmInputPass, 0).x * int(textureSize(PfmInputPass, 0).x / params.pfm_ccWantRes + 0.5);
    float lpWindowNarrowSize = lowpassWindowStdNarrowSize * ccSize / ccStdSize;
    float lpSincNarrowRate = lowpassSincStdNarrowRate / ccSize * ccStdSize;
    float lpWindowBaseSize = lowpassWindowStdBaseSize * ccSize / ccStdSize;
    float lpSincBaseRate = lowpassSincStdBaseRate / ccSize * ccStdSize;

    // Effective x-coordinates of the four samples within this shader fragment.
    vec4 subX = (vTexCoord.x * params.OutputSize.x + vec4(-3.0/8.0, -1.0/8.0, 1.0/8.0, 3.0/8.0)) * params.OutputSize.z;
    
    float Y = 0;
    float I = 0; // Actually B-Y
    float Q = 0; // Actually R-Y
    float Ylp = 0;
    
    float hammingSize = params.pfm_demodType > 0.5 ? lpWindowBaseSize : lpWindowNarrowSize;
    float sincRate = params.pfm_demodType > 0.5 ? lpSincBaseRate : lpSincNarrowRate;

    float notchHammingSize = notchHammingStdSizeRatio * ccSize;
    float notchSincRate = notchSincStdRateRatio / ccSize;

    if(params.pfm_alt_notch > 0.5) {
        float altNotchStrength = 1 + 9 * params.pfm_sharpness;
        //notchHammingSize = hammingSize / altNotchStrength;
        //notchSincRate = sincRate * altNotchStrength;
    }
    
    float minX = (int((vTexCoord.x - max(hammingSize, notchHammingSize) / 2.0) * params.SourceSize.x - 0.0001) + 0.5) * params.SourceSize.z;
    float maxX = (int((vTexCoord.x + max(hammingSize, notchHammingSize) / 2.0) * params.SourceSize.x + 0.0001) + 0.5) * params.SourceSize.z;
    float sums = 0;
    float sumsNotch = 0;
    float sumsLowpass = 0;
    float fullOffset = params.pfm_offsetInit + 1.0 / params.pfm_offsetLine * vTexCoord.y * params.SourceSize.y + 1.0 / params.pfm_offsetFrame * (params.FrameCount % int(0.5 + params.pfm_offsetFrameMod));
    vec4 xSplit = vec4(-3.0/8.0, -1.0/8.0, 1.0/8.0, 3.0/8.0) * params.SourceSize.z;
    for(float offX = minX; offX < maxX + 0.0001; offX += params.SourceSize.z) {
        vec4 thisPixel = texture(Source, vec2(offX, vTexCoord.y));
        vec4 phase = ((offX + xSplit) / ccSize + fullOffset) * 2 * pi;
        vec4 firFilt = windowSinc(offX - vTexCoord.x + xSplit, hammingSize, sincRate);
        sums += dot(firFilt, vec4(1.0));
        // This is a B-Y R-Y demodulation. Dividing by scaling factors is required.
        I += dot(firFilt * (vec4(thisPixel.y) + vec4(thisPixel.x) * sin(phase) * 2 / 0.492111), vec4(1));
        Q += dot(firFilt * (vec4(thisPixel.z) + vec4(thisPixel.x) * cos(phase) * 2 / 0.877283), vec4(1));
        firFilt = windowSinc(offX - vTexCoord.x + xSplit, lpWindowBaseSize, lpSincBaseRate);
        sumsLowpass += dot(firFilt, vec4(1.0));
        vec4 signal = vec4(thisPixel.x) + vec4(thisPixel.y) * sin(phase) * 0.492111 + vec4(thisPixel.z) * cos(phase) * 0.877283;
        Ylp += dot(firFilt * signal, vec4(1));
        vec4 notchFilt;
        //if(params.pfm_alt_notch < 0.5) {
            // Notch filter for Y
            notchFilt = windowSincNotch(offX - vTexCoord.x + xSplit, notchHammingSize, notchSincRate, ccSize);
        //} else {
            // Low pass filter for Y
        //    notchFilt = windowSinc(offX - vTexCoord.x + xSplit, notchHammingSize, notchSincRate);
        //}
        sumsNotch += dot(notchFilt, vec4(1));
        Y += dot(notchFilt, signal);
    }
    I /= sums;
    Q /= sums;
    Y /= sumsNotch;
    Ylp /= sumsLowpass;

    // if(params.pfm_alt_notch > 0.5) {
        // Y = Ylp;
    // }

    // The w value is used by the comb filter pass.
    //FragColor = vec4(vec3(Y, I, Q), dot(texture(Source, vTexCoord), vec4(0.25)));
    FragColor = vec4(Y, I, Q, Ylp);
}
