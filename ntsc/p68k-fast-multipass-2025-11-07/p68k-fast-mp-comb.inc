
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
    float pfm_comb,
          pfm_comb_sharpness,
          pfm_offsetInit,
          pfm_offsetLine,
          pfm_offsetFrame,
          pfm_offsetFrameMod,
          pfm_ccWantRes,
          pfm_ccNum,
          pfm_ccDenom,
          pfm_combShaderglassFix;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma parameter pfm_comb "Comb filter 0:Off 1:2-line 2:3-line 3:Adaptive" 0 0 3 1
#pragma parameter pfm_combShaderglassFix "ShaderGlass comb filter workaround" 0 0 1 1
//#pragma parameter pfm_comb_sharpness "Comb filter sharpness" 1.0 0.0 10.0 0.05
//#pragma parameter pfm_comb_ymode "Comb filter alternate mode" 0 0 2 1
//#pragma parameter pfm_comb_ymode2 "Comb filter alternate mode 2" 0 0 2 1
//#pragma parameter pfm_comb_ymode3 "Comb filter alternate mode 3" 0 0 2 1
//#pragma parameter pfm_comb_ymode4 "Comb filter alternate mode 4" 0 0 1 1
#pragma parameter pfm_ccWantRes "Console default resolution in pixels (0=Don't care)" 0 0 10000 1
#pragma parameter pfm_ccNum "Color carrier wavelength numerator" 1 1 10000 1
#pragma parameter pfm_ccDenom "Color carrier wavelength denominator" 1 1 10000 1
#pragma parameter pfm_offsetInit "Color initial offset" 0 0 1 0.01
#pragma parameter pfm_offsetLine "Color per-line offset" 2 -10 10 1
#pragma parameter pfm_offsetFrame "Color per-frame offset" 2 -10 10 1
#pragma parameter pfm_offsetFrameMod "Color per-frame modulus" 2 1 10 1

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
#ifdef NO_NOISE
layout(set = 0, binding = 4) uniform sampler2D PfmEncodePass;
#define RAW_SOURCE PfmEncodePass
#else
layout(set = 0, binding = 4) uniform sampler2D PfmNoisePass;
#define RAW_SOURCE PfmNoisePass
#endif

float mixMinimumMagnitude(vec2 vector1, vec2 vector2, float tolerance) {
    // Screw this, just do a brute force search.
    // Start from the center, and gradually go further out.
    // Upon reaching a desired tolerance level, exit early.
    // After reaching the maximum number of iterations, just pick the best solution.
    int maxIter = 15;
    float bestDist = 100;
    float bestRatio;
    for(int i = 0; i <= maxIter; i++) {
        float ratio = 0.5 + 0.5 * float(i) / float(maxIter);
        vec2 mixed = mix(vector1, vector2, ratio);
        float dista = distance(vec2(0), mixed);
        if(dista <= tolerance) {
            return ratio;
        }
        if(dista < bestDist) {
            bestDist = dista;
            bestRatio = ratio;
        }
        ratio = 0.5 - 0.5 * float(i) / float(maxIter);
        mixed = mix(vector1, vector2, ratio);
        dista = distance(vec2(0), mixed);
        if(dista <= tolerance) {
            return ratio;
        }
        if(dista < bestDist) {
            bestDist = dista;
            bestRatio = ratio;
        }
    }
    return bestRatio;
}

void main() {
    float ccSize = params.pfm_ccWantRes < 0.5 ? 12.0 / (256.0 * 8.0) : params.pfm_ccNum / params.pfm_ccDenom / textureSize(PfmInputPass, 0).x * int(textureSize(PfmInputPass, 0).x / params.pfm_ccWantRes + 0.5);

    float offsetSamplesF = 4 * params.SourceSize.x * ccSize * (mod(0.5 - 1.0 / params.pfm_offsetLine, 1.0));
    int offsetSamples = offsetSamplesF >= 0 ? int(offsetSamplesF + 0.5) : int(offsetSamplesF - 0.5);

    float offsetPixelsPrev = floor((-offsetSamples + 0.5) / 4.0);
    int offsetSubpixelsPrev = (-offsetSamples % 4 + 4) % 4;
    float offsetPixelsNext = floor((offsetSamples + 0.5) / 4.0);
    int offsetSubpixelsNext = (offsetSamples % 4 + 4) % 4;

    float inlineOffsetSamplesF = 4 * params.SourceSize.x * ccSize * 0.5;
    int inlineOffsetSamples = inlineOffsetSamplesF >= 0 ? int(inlineOffsetSamplesF + 0.5) : int(inlineOffsetSamplesF - 0.5);

    float offsetPixelsLeft = floor((-inlineOffsetSamples + 0.5) / 4.0);
    int offsetSubpixelsLeft = (-inlineOffsetSamples % 4 + 4) % 4;
    float offsetPixelsRight = floor((inlineOffsetSamples + 0.5) / 4.0);
    int offsetSubpixelsRight = (inlineOffsetSamples % 4 + 4) % 4;

    vec4 thisYiq = texture(Source, vTexCoord);
    float thisRaw = params.pfm_combShaderglassFix < 0.5 ? texture(RAW_SOURCE, vTexCoord)[0] : thisYiq.w;
    vec4 prevYiq = texture(Source, vTexCoord + vec2(offsetPixelsPrev * params.SourceSize.z, -params.SourceSize.w));
    float prevRaw = params.pfm_combShaderglassFix < 0.5 ? texture(RAW_SOURCE, vTexCoord + vec2(offsetPixelsPrev * params.SourceSize.z, -params.SourceSize.w))[offsetSubpixelsPrev] : prevYiq.w;
    vec4 nextYiq = texture(Source, vTexCoord + vec2(offsetPixelsNext * params.SourceSize.z, params.SourceSize.w));
    float nextRaw = params.pfm_combShaderglassFix < 0.5 ? texture(RAW_SOURCE, vTexCoord + vec2(offsetPixelsNext * params.SourceSize.z, params.SourceSize.w))[offsetSubpixelsNext] : nextYiq.w;
    //vec4 leftYiq = texture(Source, vTexCoord + vec2(offsetPixelsLeft * params.SourceSize.z, 0));
    //float leftRaw = texture(RAW_SOURCE, vTexCoord + vec2(offsetPixelsLeft * params.SourceSize.z, 0))[offsetSubpixelsLeft];
    //vec4 rightYiq = texture(Source, vTexCoord + vec2(offsetPixelsRight * params.SourceSize.z, 0));
    //float rightRaw = texture(RAW_SOURCE, vTexCoord + vec2(offsetPixelsRight * params.SourceSize.z, 0))[offsetSubpixelsRight];

    if(params.pfm_comb < 0.5) {
        // No comb filter
        FragColor = vec4(thisYiq.xyz, 1.0);
    } else if(params.pfm_comb < 1.5) {
        // 2-line comb filter
        FragColor = vec4((thisRaw + prevRaw) / 2.0, (thisYiq.yz + prevYiq.yz) / 2.0, 1.0);
    } else if(params.pfm_comb < 2.5) {
        // 3-line comb filter
        FragColor = vec4((thisRaw - thisYiq.x + (prevRaw - prevYiq.x + nextRaw - nextYiq.x) / 2.0) / 2.0 + thisYiq.x, (thisYiq.yz + (prevYiq.yz + nextYiq.yz) / 2.0) / 2.0, 1.0);
    } else {
        // Adaptive 3-line comb filter

        vec2 bmyRmyScaling = vec2(0.492111, 0.877283);

        vec2 comb1 = thisYiq.yz * bmyRmyScaling - prevYiq.yz * bmyRmyScaling;
        vec2 comb2 = thisYiq.yz * bmyRmyScaling - nextYiq.yz * bmyRmyScaling;

        float ratio2 = mixMinimumMagnitude(comb1, comb2, 0.01);

        vec4 weightedAverage = mix(prevYiq, nextYiq, ratio2);
        float weightedAverageRaw = mix(prevRaw, nextRaw, ratio2);
        
        FragColor = vec4(
            thisYiq.x + (thisRaw - thisYiq.x + weightedAverageRaw - weightedAverage.x) / 2.0,
            (thisYiq.yz + weightedAverage.yz) / 2.0,
            1.0
        );
    }
}
