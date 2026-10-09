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

This pass takes either Y B-Y R-Y or YIQ and converts it into a composite video signal.
Each pixel has four samples of the video signal.

This pass should have its horizontal resolution set to whatever your PC can handle. I recommend 640.
The input should have nearest-neighbor interpolation.
The framebuffer should use floats, not integers.

*/

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;

    float pfm_modType,
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
#pragma parameter pfm_modType "Encoder lowpass -1:Off 0:Old IQ 1:Equiband B-Y R-Y 2:Narrowband" 1 -1 2 1

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

void main() {

///////////////////////////
// Standard constants
///////////////////////////

    // "Size" means wavelength in microseconds.
    // "Rate" means frequency in megahertz.
    float ccStdSize = 1 / (5.0 * 63.0 / 88.0); // About 3.579545 MHz
    // At 0.4 MHz, less than 2 db down. At 0.5 MHz, less than 6 db down. At 0.6 MHz, at least 6 db down.
    float lowpassWindowStdNarrowSize = 5.34;
    float lowpassSincStdNarrowRate = 0.459;
    // At 1.3 MHz, less than 2 db down. At 3.6 MHz, at least 20 db down.
    float lowpassWindowStdBaseSize = 0.573;
    float lowpassSincStdBaseRate = 0.747;

///////////////////////////////////////
// Corrected constants
// Relative to input size
///////////////////////////////////////

    // There isn't a standard for the duration of the active area of the line.
    // I have set the default such that the number of color carrier cycles per the active area is the same as in the NES and SNES.
    // On the NES and SNES, there are 256 pixels horizontally, and the color carrier is 1.5 pixels wide.
    // Assuming the standard frequency, that makes each line 47.678306816 microseconds long.
    float ccSize = params.pfm_ccWantRes < 0.5 ? 12.0 / (256.0 * 8.0) : params.pfm_ccNum / params.pfm_ccDenom / textureSize(PfmInputPass, 0).x * int(textureSize(PfmInputPass, 0).x / params.pfm_ccWantRes + 0.5);
    float lpWindowNarrowSize = lowpassWindowStdNarrowSize * ccSize / ccStdSize;
    float lpSincNarrowRate = lowpassSincStdNarrowRate / ccSize * ccStdSize;
    float lpWindowBaseSize = lowpassWindowStdBaseSize * ccSize / ccStdSize;
    float lpSincBaseRate = lowpassSincStdBaseRate / ccSize * ccStdSize;

    // Effective x-coordinates of the four samples within this shader fragment.
    vec4 subX = (vTexCoord.x * params.OutputSize.x + vec4(-3.0/8.0, -1.0/8.0, 1.0/8.0, 3.0/8.0)) * params.OutputSize.z;
    int stepAmt = int(params.OutputSize.x * 4.0 / params.SourceSize.x + 0.5001);
    float stepRate = params.SourceSize.z / stepAmt;
    
    vec4 Y;
    for(int i = 0; i < 4; i++) {
        Y[i] = texture(Source, vec2(subX[i], vTexCoord.y)).r;
    }
    vec4 I = vec4(0); // Might actually be B-Y
    vec4 Q = vec4(0); // Might actually be R-Y
    if(params.pfm_modType > 0.5) {
        float hammingSize = params.pfm_modType < 1.5 ? lpWindowBaseSize : lpWindowNarrowSize;
        float sincRate = params.pfm_modType < 1.5 ? lpSincBaseRate : lpSincNarrowRate;
        
        float minX = (int((subX[0] - hammingSize / 2.0) * params.SourceSize.x - 0.0001) + 0.5) * params.SourceSize.z;
        float maxX = (int((subX[3] + hammingSize / 2.0) * params.SourceSize.x + 0.0001) + 0.5) * params.SourceSize.z;
        vec4 sums = vec4(0);
        float offX = minX;
        for(int i = 0; i < 70; i++) {
            vec2 thisPixel = texture(Source, vec2(offX, vTexCoord.y)).gb;
            for(int i = 0; i < stepAmt; i++) {
                vec4 firFilt = windowSinc(subX - offX, hammingSize, sincRate);
                sums += firFilt;
                I += firFilt * thisPixel.r;
                Q += firFilt * thisPixel.g;
                offX += stepRate; // Increment outer for-loop
            }
            if(offX >= maxX + 0.0001) {
                break;
            }
        }
        I /= sums;
        Q /= sums;
    } else if(params.pfm_modType > -0.5) {
        Y = I = Q = vec4(0);
    } else {
        for(int i = 0; i < 4; i++) {
            I[i] = texture(Source, vec2(subX[i], vTexCoord.y)).g;
            Q[i] = texture(Source, vec2(subX[i], vTexCoord.y)).b;
        }
    }

    mat3 rgbToYiq = mat3(
        0.299, 0.5959, 0.2115,
        0.587, -0.2746, -0.5227,
        0.114, -0.3213, 0.3112
    );
    mat3 rgbToYBmyRmy = mat3(
        0.299, -0.299, 0.701,
        0.587, -0.587, -0.587,
        0.114, 0.886, -0.114
    );

    vec3 resultYC = vec3(
        dot(Y, vec4(0.25)),
        dot(I, vec4(0.25)),
        dot(Q, vec4(0.25))
    );

    if(params.pfm_modType > -0.5 && params.pfm_modType < 0.5) {
        // I/Q
        FragColor = vec4(inverse(rgbToYiq) * resultYC, 1.0);
    } else {
        // B-Y/R-Y
        FragColor = vec4(inverse(rgbToYBmyRmy) * resultYC, 1.0);
    }
}
