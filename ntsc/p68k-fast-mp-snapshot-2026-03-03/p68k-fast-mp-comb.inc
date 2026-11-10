
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

#pragma name PfmCombPass

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
    float pfm_comb,
          pfm_comb_sharpness,
          pfm_comb_ymode,
          pfm_offsetInit,
          pfm_offsetLine,
          pfm_offsetFrame,
          pfm_offsetFrameMod,
          pfm_ccWantRes,
          pfm_ccNum,
          pfm_ccDenom,
          pfm_comb_ymode2,
          pfm_comb_ymode3,
          pfm_comb_ymode4;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;

    float pfm_remod;
    float pfm_forceInterlace;
    float pfm_comb_corrMode;
} global;

#pragma parameter pfm_remod "Replace Y notch with C remod instead" 1 0 1 1
#pragma parameter pfm_comb "Comb filter 0:Off 1:2-line 2:3-line 3:Adaptive 4:Adapt+Notch" 0 -1 5 1
#pragma parameter pfm_comb_corrMode "Correlation detection mode" 0 0 8 1
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
#pragma parameter pfm_forceInterlace "Force enable interlace: 0:Off 1:On" 0 0 1 1

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
layout(set = 0, binding = 2) uniform sampler2D PfmDecodePass;
layout(set = 0, binding = 3) uniform sampler2D PfmInputPass;
layout(set = 0, binding = 4) uniform sampler2D PfmDecodePassFeedback;
#ifdef NO_NOISE
layout(set = 0, binding = 5) uniform sampler2D PfmEncodePass;
layout(set = 0, binding = 6) uniform sampler2D PfmEncodePassFeedback;
#define RAW_SOURCE PfmEncodePass
#define RAW_SOURCE_FEEDBACK PfmEncodePassFeedback
#else
layout(set = 0, binding = 5) uniform sampler2D PfmNoisePass;
layout(set = 0, binding = 6) uniform sampler2D PfmNoisePassFeedback;
#define RAW_SOURCE PfmNoisePass
#define RAW_SOURCE_FEEDBACK PfmNoisePassFeedback
#endif
#ifdef DUAL_DEMOD_FILT
layout(set = 0, binding = 7) uniform sampler2D PfmDecode2Pass;
#endif

float mixMinimumMagnitude(vec2 vector1, vec2 vector2, float tolerance) {

    if(global.pfm_comb_corrMode < 0.5) {
        if(abs(vector1.x - vector2.x) <= tolerance && abs(vector1.y - vector2.y) <= tolerance) {
            // Both points are almost identical in both axes.
            // The distance is rectangular instead of circular on purpose for consistency with the single-axis checks.

            return 0.5;
        } else if(abs(vector1.x - vector2.x) <= tolerance) {
            // Both points are almost identical in the x-axis.

            if(vector1.y * vector2.y >= 0) {
                // Both points' y values have the same sign

                if(abs(vector1.y) < abs(vector2.y)) {
                    return 0.0;
                } else {
                    return 1.0;
                }
            } else {
                // Points' y-values have different signs.

                return abs(0.0 - vector1.y) / abs(vector2.y - vector1.y);
            }
        } else if(abs(vector1.y - vector2.y) <= tolerance) {
            // Both points are almost identical in the y-axis.

            if(vector1.x * vector2.x >= 0) {
                // Both points' x values have the same sign

                if(abs(vector1.x) < abs(vector2.x)) {
                    return 0.0;
                } else {
                    return 1.0;
                }
            } else {
                // Points' x-values have different signs.
                
                return abs(0.0 - vector1.x) / abs(vector2.x - vector1.x);
            }
        } else {
            // Points are significantly different from each other in both the x-axis and the y-axis.

            float mA = (vector1.y - vector2.y) / (vector1.x - vector2.x);
            float mB = -1.0 / mA;

            float finalX = (vector1.y - mA * vector1.x) / (mB - mA);
            float finalRatio = (finalX - vector1.x) / (vector2.x - vector1.x);

            if(finalRatio >= 0.0 && finalRatio <= 1.0) {
                return finalRatio;
            } else {
                if(distance(vec2(0), vector1) < distance(vec2(0), vector2)) {
                    return 0.0;
                } else {
                    return 1.0;
                }
            }
        }
    } else {
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
}

float mixMaximumMagnitude(vec2 vector1, vec2 vector2) {
    // Screw this, just do a brute force search.
    // Start from the center, and gradually go further out.
    // Iterate through all options, and pick the best solution.
    int maxIter = 15;
    float bestDist = 0;
    float bestRatio;
    for(int i = 0; i <= maxIter; i++) {
        float ratio = 0.5 + 0.5 * float(i) / float(maxIter);
        vec2 mixed = mix(vector1, vector2, ratio);
        float dista = distance(vec2(0), mixed);
        if(dista > bestDist) {
            bestDist = dista;
            bestRatio = ratio;
        }
        ratio = 0.5 - 0.5 * float(i) / float(maxIter);
        mixed = mix(vector1, vector2, ratio);
        dista = distance(vec2(0), mixed);
        if(dista > bestDist) {
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


    vec4 thisYiq = texture(PfmDecodePass, vTexCoord);
    float thisRaw = texture(RAW_SOURCE, vTexCoord)[0];
    vec4 prevYiq = texture(PfmDecodePass, vTexCoord + vec2(offsetPixelsPrev * params.SourceSize.z, -params.SourceSize.w));
    float prevRaw = texture(RAW_SOURCE, vTexCoord + vec2(offsetPixelsPrev * params.SourceSize.z, -params.SourceSize.w))[offsetSubpixelsPrev];
    vec4 nextYiq = texture(PfmDecodePass, vTexCoord + vec2(offsetPixelsNext * params.SourceSize.z, params.SourceSize.w));
    float nextRaw = texture(RAW_SOURCE, vTexCoord + vec2(offsetPixelsNext * params.SourceSize.z, params.SourceSize.w))[offsetSubpixelsNext];
    //vec4 leftYiq = texture(PfmDecodePass, vTexCoord + vec2(offsetPixelsLeft * params.SourceSize.z, 0));
    //float leftRaw = texture(RAW_SOURCE, vTexCoord + vec2(offsetPixelsLeft * params.SourceSize.z, 0))[offsetSubpixelsLeft];
    //vec4 rightYiq = texture(PfmDecodePass, vTexCoord + vec2(offsetPixelsRight * params.SourceSize.z, 0));
    //float rightRaw = texture(RAW_SOURCE, vTexCoord + vec2(offsetPixelsRight * params.SourceSize.z, 0))[offsetSubpixelsRight];
#ifdef DUAL_DEMOD_FILT
    vec4 thisYiqNarrow = texture(PfmDecode2Pass, vTexCoord);
    vec4 prevYiqNarrow = texture(PfmDecode2Pass, vTexCoord + vec2(offsetPixelsPrev * params.SourceSize.z, -params.SourceSize.w));
    vec4 nextYiqNarrow = texture(PfmDecode2Pass, vTexCoord + vec2(offsetPixelsNext * params.SourceSize.z, params.SourceSize.w));
#endif

    if(global.pfm_remod > 0.5) {
        float ccSize = params.pfm_ccWantRes < 0.5 ? 12.0 / (256.0 * 8.0) : params.pfm_ccNum / params.pfm_ccDenom / textureSize(PfmInputPass, 0).x * int(textureSize(PfmInputPass, 0).x / params.pfm_ccWantRes + 0.5);
        float fullOffset = params.pfm_offsetInit + 1.0 / params.pfm_offsetLine * vTexCoord.y * params.SourceSize.y + 1.0 / params.pfm_offsetFrame * ((params.FrameCount % int(0.5 + params.pfm_offsetFrameMod) + (params.OutputSize.y > 300 || global.pfm_forceInterlace > 0.5 ? params.FrameCount / 2 % int(0.5 + params.pfm_offsetFrameMod) : 0)) % int(0.5 + params.pfm_offsetFrameMod));
        
        float angularOff = ((vTexCoord.x - (3.0 / 8.0) * params.OutputSize.z) / ccSize + fullOffset) * 2 * pi;
        float remod = (0.492111 * thisYiq.y * sin(angularOff) + 0.877283 * thisYiq.z * cos(angularOff));

        float angularOffNeg = angularOff + pi;
        float remodPrev = (0.492111 * prevYiq.y * sin(angularOffNeg) + 0.877283 * prevYiq.z * cos(angularOffNeg));
        float remodNext = (0.492111 * nextYiq.y * sin(angularOffNeg) + 0.877283 * nextYiq.z * cos(angularOffNeg));
        
        thisYiq.x = thisRaw - remod;
        thisYiq.w = remod;
        prevYiq.x = prevRaw - remodPrev;
        prevYiq.w = remodPrev;
        nextYiq.x = nextRaw - remodNext;
        nextYiq.w = remodNext;
#ifdef DUAL_DEMOD_FILT
        thisYiqNarrow.x = thisRaw - (0.492111 * thisYiqNarrow.y * sin(angularOff) + 0.877283 * thisYiqNarrow.z * cos(angularOff));
        thisYiqNarrow.w = (0.492111 * thisYiqNarrow.y * sin(angularOff) + 0.877283 * thisYiqNarrow.z * cos(angularOff));
        prevYiqNarrow.x = prevRaw - (0.492111 * prevYiqNarrow.y * sin(angularOffNeg) + 0.877283 * prevYiqNarrow.z * cos(angularOffNeg));
        prevYiqNarrow.w = (0.492111 * prevYiqNarrow.y * sin(angularOffNeg) + 0.877283 * prevYiqNarrow.z * cos(angularOffNeg));
        nextYiqNarrow.x = nextRaw - (0.492111 * nextYiqNarrow.y * sin(angularOffNeg) + 0.877283 * nextYiqNarrow.z * cos(angularOffNeg));
        nextYiqNarrow.w = (0.492111 * nextYiqNarrow.y * sin(angularOffNeg) + 0.877283 * nextYiqNarrow.z * cos(angularOffNeg));
#endif
    }

    if(params.pfm_comb < -0.5) {
        // Unfiltered Y, and lowpass-filtered C.
        FragColor = vec4(thisRaw, thisYiq.yz, 1.0);
    } else if(params.pfm_comb < 0.5) {
        // Notch-filtered Y, and lowpass-filtered C.
        FragColor = vec4(thisYiq.xyz, 1.0);
    } else if(params.pfm_comb < 1.5) {
        // 2-line comb filter
        FragColor = vec4((thisRaw + prevRaw) / 2.0, (thisYiq.yz + prevYiq.yz) / 2.0, 1.0);
    } else if(params.pfm_comb < 2.5) {
        // 3-line comb filter
        FragColor = vec4((thisRaw - thisYiq.x + (prevRaw - prevYiq.x + nextRaw - nextYiq.x) / 2.0) / 2.0 + thisYiq.x, (thisYiq.yz + (prevYiq.yz + nextYiq.yz) / 2.0) / 2.0, 1.0);
    } else if(params.pfm_comb < 4.5) {
        // Adaptive 3-line comb filter

        vec2 bmyRmyScaling = vec2(0.492111, 0.877283);

        vec2 comb1, comb2;
        float ratio1 = 1.0, ratio2, ratio3 = 0.0;

        // Find similar chroma across all frequencies.
        comb1 = thisYiq.yz * bmyRmyScaling - prevYiq.yz * bmyRmyScaling;
        comb2 = thisYiq.yz * bmyRmyScaling - nextYiq.yz * bmyRmyScaling;
        ratio2 = mixMinimumMagnitude(comb1, comb2, 0.01);
#ifdef DUAL_DEMOD_FILT
        if(global.pfm_comb_corrMode < 0.5 || global.pfm_comb_corrMode > 3.5) {
            // Find similar low-frequency chroma and opposite high-frequency chroma.
            // In other words, we expect most low-frequency chroma information
            // to be chroma, and most high-frequency chroma information to be luma.
            comb1 = (thisYiq + prevYiq - 2 * prevYiqNarrow).yz * bmyRmyScaling;
            comb2 = (thisYiq + nextYiq - 2 * nextYiqNarrow).yz * bmyRmyScaling;
            ratio2 = mixMinimumMagnitude(comb1, comb2, 0.01);
        }
#endif

        vec4 weightedAverage = mix(prevYiq, nextYiq, ratio2);
        float weightedAverageRaw = mix(prevRaw, nextRaw, ratio2);

#ifdef DUAL_DEMOD_FILT
        if(global.pfm_comb_corrMode > 1.5 && global.pfm_comb_corrMode < 2.5) {
            // Find similar chroma in low frequencies.
            comb1 = thisYiqNarrow.yz * bmyRmyScaling - prevYiqNarrow.yz * bmyRmyScaling;
            comb2 = thisYiqNarrow.yz * bmyRmyScaling - nextYiqNarrow.yz * bmyRmyScaling;
            ratio2 = mixMinimumMagnitude(comb1, comb2, 0.01);
            weightedAverage = mix(prevYiq, nextYiq, ratio2);
            weightedAverageRaw = mix(prevRaw, nextRaw, ratio2);
        } else if(global.pfm_comb_corrMode > 2.5 && global.pfm_comb_corrMode < 3.5) {
            
            // Another idea, because the next one ("Adaptively comb filter
            // low-frequency chroma and high-frequency chroma separately from
            // each other") looked bad.
            
            // This idea is about trying to detect whether we're looking at
            // horizontal lines or at vertical lines.
            // Horizontal lines have little high frequency information.
            // Horizontal lines should be notch-filtered.
            // Vertical lines have a lot of high frequency information.
            // Vertical lines should be comb-filtered.
            
            // We will first attempt the comb filter normally and see if the
            // result has much high frequency information.

            vec4 weightedAverageHigh = mix(prevYiq - prevYiqNarrow, nextYiq - nextYiqNarrow, ratio2);
            vec4 weightedAverageLow = mix(prevYiqNarrow, nextYiqNarrow, ratio2);
            
            float combAmtHigh = dot(abs(weightedAverageHigh.yz - (thisYiq.yz - thisYiqNarrow.yz)) / 2.0, bmyRmyScaling);
            float combAmtLow = dot(abs(weightedAverageLow.yz - (thisYiqNarrow.yz)) / 2.0, bmyRmyScaling);
            
            float threshold = 0.01;
            float combRate = 0;
            if(max(combAmtHigh, combAmtLow) < threshold) {
                combRate = 0;
            } else {
                combRate = 1 - combAmtHigh / max(combAmtLow, combAmtHigh);
            }

            FragColor = mix(vec4(
                thisYiq.x + (thisRaw - thisYiq.x + weightedAverageRaw - weightedAverage.x) / 2.0,
                (thisYiq.yz + weightedAverage.yz) / 2.0,
                1.0
            ), thisYiq, combRate);
            return;
        } else if(global.pfm_comb_corrMode > 3.5 && global.pfm_comb_corrMode < 4.5) {
            // Adaptively comb filter low-frequency chroma and high-frequency
            // chroma separately from each other.
            // Y is determined from the high-frequency chroma comb filter only.
            
            // Adaptively filter the high-frequency region of chroma.
            // Most interference from luma tends to become high-frequency
            // chroma. Whenever high-frequency chroma is present, it tends to
            // coincide with a lot of high-frequency luma. In some rarer
            // cases, such as with Crash Bandicoot 2 and 3's text, you'll get
            // enough high-frequency chroma to drown out the high-frequency
            // luma, but that's uncommon.
            // Because of this, we adaptively pick the comb filter that
            // minimizes the average of the high-frequency chroma region,
            // in an effort to minimize interfering high-frequency luma at the
            // expense of high-frequency chroma.
            comb1 = (thisYiq - thisYiqNarrow + prevYiq - prevYiqNarrow).yz * bmyRmyScaling;
            comb2 = (thisYiq - thisYiqNarrow + nextYiq - nextYiqNarrow).yz * bmyRmyScaling;
            ratio2 = mixMinimumMagnitude(comb1, comb2, 0.01);
            vec3 weightedAverageHigh = mix(prevYiq - prevYiqNarrow, nextYiq - nextYiqNarrow, ratio2).wyz;

            // Adaptively filter the low-frequency region of chroma.
            // Although high-frequency luma interference definitely can and
            // does appear in this region, we can safely assume that most of
            // the information here is chroma.
            // Because of this, we adaptively pick the comb filter that
            // minimizes the discovered chroma difference between lines.
            vec2 comb12 = (thisYiqNarrow - prevYiqNarrow).yz * bmyRmyScaling;
            vec2 comb22 = (thisYiqNarrow - nextYiqNarrow).yz * bmyRmyScaling;
            float ratio22 = mixMinimumMagnitude(comb12, comb22, 0.01);
            vec3 weightedAverageLow = mix(prevYiqNarrow, nextYiqNarrow, ratio22).wyz;

            // Y uses the high-frequency chroma comb filter.
            //float invY = mix(prevYiq.x, nextYiq.x, ratio2);

            FragColor = vec4(thisYiq.x + (thisYiq.w + weightedAverageHigh.x + weightedAverageLow.x) / 2, (thisYiq.yz + weightedAverageHigh.yz + weightedAverageLow.yz) / 2.0, 1.0);
            return;
        } else if(global.pfm_comb_corrMode > 4.5 && global.pfm_comb_corrMode < 8.5) {

            // These next two ideas use five consecutive lines instead of three.
            // For now, they only work if the color carrier alternates perfectly by 180 degrees per line.

            vec4 prevPrevYiq = texture(PfmDecodePass, vec2(vTexCoord.x, vTexCoord.y - params.SourceSize.w * 2));
            vec4 nextNextYiq = texture(PfmDecodePass, vec2(vTexCoord.x, vTexCoord.y - params.SourceSize.w * 2));

            if(global.pfm_comb_corrMode < 5.5) {
                // Find similar chroma across all frequencies, skipping over one line.
                comb1 = (prevPrevYiq.yz - thisYiq.yz) * bmyRmyScaling;
                comb2 = (nextNextYiq.yz - thisYiq.yz) * bmyRmyScaling;
                ratio2 = mixMinimumMagnitude(comb1, comb2, 0.01);
                
                // Still comb filter without skipping lines.
                weightedAverage = mix(prevYiq, nextYiq, ratio2);
                weightedAverageRaw = mix(prevRaw, nextRaw, ratio2);
            } else if(global.pfm_comb_corrMode < 6.5) {
                // Adaptively comb filter the previous line, finding similar chroma across all frequencies
                comb1 = (prevPrevYiq.yz - prevYiq.yz) * bmyRmyScaling;
                comb2 = (thisYiq.yz - prevYiq.yz) * bmyRmyScaling;
                float ratioPrev = 2 * max(0, mixMinimumMagnitude(comb1, comb2, 0.01) - 0.5);

                // Adaptively comb filter the next line in the same way
                comb1 = (nextNextYiq.yz - nextYiq.yz) * bmyRmyScaling;
                comb2 = (thisYiq.yz - nextYiq.yz) * bmyRmyScaling;
                float ratioNext = 2 * max(0, mixMinimumMagnitude(comb1, comb2, 0.01) - 0.5);

                float ratioSelf = ratioPrev + ratioNext;
                if(ratioSelf > 1.0) {
                    ratioPrev /= ratioSelf;
                    ratioNext /= ratioSelf;
                    ratioSelf = 1.0;
                }

                float fullY = thisYiq.x + ratioPrev * (thisRaw - thisYiq.x + prevRaw - prevYiq.x) / 2.0 + ratioNext * (thisRaw - thisYiq.x + nextRaw - nextYiq.x) / 2.0;
                vec2 fullC = ratioPrev * (thisYiq.yz + prevYiq.yz) / 2.0 + ratioNext * (thisYiq.yz + nextYiq.yz) / 2.0 + (1 - ratioPrev - ratioNext) * thisYiq.yz;
                FragColor = vec4(fullY, fullC, 1.0);
                return;
            } else if(global.pfm_comb_corrMode < 7.5) {
                // Adaptively comb filter the previous line, finding similar chroma across all frequencies
                comb1 = (prevPrevYiq.yz - prevYiq.yz) * bmyRmyScaling;
                comb2 = (thisYiq.yz - prevYiq.yz) * bmyRmyScaling;
                float ratioPrev = 2 * max(0, mixMinimumMagnitude(comb1, comb2, 0.01) - 0.5);

                // Adaptively comb filter the next line in the same way
                comb1 = (nextNextYiq.yz - nextYiq.yz) * bmyRmyScaling;
                comb2 = (thisYiq.yz - nextYiq.yz) * bmyRmyScaling;
                float ratioNext = 2 * max(0, mixMinimumMagnitude(comb1, comb2, 0.01) - 0.5);

                // Adaptively comb filter the the current line in the same way
                comb1 = (prevYiq.yz - thisYiq.yz) * bmyRmyScaling;
                comb2 = (nextYiq.yz - thisYiq.yz) * bmyRmyScaling;
                float ratioSelf = mixMinimumMagnitude(comb1, comb2, 0.01);
                float ratioSelfNext = 2 * max(0, ratioSelf - 0.5);
                float ratioSelfPrev = 1 - ratioSelfNext;

                // Look for where the consecutive adaptive comb filters agree.
                float finalRatioPrev = max(ratioPrev, ratioSelfPrev);
                float finalRatioNext = max(ratioNext, ratioSelfNext);
                if(finalRatioPrev + finalRatioNext > 1.0) {
                    float finalSum = finalRatioPrev + finalRatioNext;
                    finalRatioPrev /= finalSum;
                    finalRatioNext /= finalSum;
                }

                float fullY = thisYiq.x + finalRatioPrev * (thisRaw - thisYiq.x + prevRaw - prevYiq.x) / 2.0 + finalRatioNext * (thisRaw - thisYiq.x + nextRaw - nextYiq.x) / 2.0;
                vec2 fullC = (1 - finalRatioPrev - finalRatioNext) * thisYiq.yz + finalRatioPrev * (thisYiq.yz + prevYiq.yz) / 2.0 + finalRatioNext * (thisYiq.yz + nextYiq.yz) / 2.0;
                FragColor = vec4(fullY, fullC, 1.0);
                return;
            }
        }
#endif

#ifdef DUAL_DEMOD_FILT
        if(params.pfm_comb < 3.5) {
#endif
            FragColor = vec4(
                thisYiq.x + (thisRaw - thisYiq.x + weightedAverageRaw - weightedAverage.x) / 2.0,
                (thisYiq.yz + weightedAverage.yz) / 2.0,
                1.0
            );
#ifdef DUAL_DEMOD_FILT
        } else {
            float threshold = 0.02;
            float threshold2 = 0.05;
            float dist = distance(vec2(0), (thisYiq.yz - thisYiqNarrow.yz) * bmyRmyScaling);
            if(dist < threshold) {
                ratio1 = 0;
            } else if(dist < threshold2) {
                ratio1 = (dist - threshold) / (threshold2 - threshold);
            } else {
                ratio1 = 1;
            }
            float threshold3 = 0.01;
            float threshold4 = 0.05;
            float dist2 = distance(thisYiq.yz * bmyRmyScaling, weightedAverage.yz * bmyRmyScaling);
            if(dist2 < threshold3) {
                ratio3 = 0;
            } else if(dist2 < threshold4) {
                ratio3 *= (dist2 - threshold3) / (threshold4 - threshold3);
            } else {
                ratio3 = 1;
            }
            ratio1 = 1 - (1 - ratio1) * ratio3;

            FragColor = mix(vec4(
                thisYiq.x,
                thisYiq.yz,
                1.0
            ), vec4(
                thisYiq.x + (thisRaw - thisYiq.x + weightedAverageRaw - weightedAverage.x) / 2.0,
                (thisYiq.yz + weightedAverage.yz) / 2.0,
                1.0
            ), ratio1);
        }
#endif
    } else {
        // Average consecutive frames
        vec4 thisYiqFeedback = texture(PfmDecodePassFeedback, vTexCoord);
        float thisRawFeedback = texture(RAW_SOURCE_FEEDBACK, vTexCoord)[0];
        FragColor = (vec4(thisRaw + thisYiq.x, thisYiq.yz, 1.0) + vec4(thisRawFeedback - thisYiqFeedback.x, thisYiqFeedback.yz, 1.0)) / 2.0;
    }
}
