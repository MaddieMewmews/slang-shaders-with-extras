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
    float pfm_alt_notch,
          pfm_comb,
          pfm_comb_sharpness,
          pfm_comb_ymode,
          pfm_offsetInit,
          pfm_offsetLine,
          pfm_offsetFrame,
          pfm_offsetFrameMod,
          pfm_ccWantRes,
          pfm_ccNum,
          pfm_ccDenom,
          pfm_comb_ymode2;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma parameter pfm_alt_notch "Non-comb filter type: 0:Notch 1:Lowpass" 0 0 1 1
#pragma parameter pfm_comb "Comb filter 0:Off 1: 2-line 2: 3-line 3: 3-line Adaptive" 0 0 3 1
#pragma parameter pfm_comb_sharpness "Comb filter sharpness" 1.0 0.0 10.0 0.05
#pragma parameter pfm_comb_ymode "Comb filter alternate mode" 0 0 2 1
#pragma parameter pfm_comb_ymode2 "Comb filter alternate mode 2" 0 0 2 1
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
layout(set = 0, binding = 4) uniform sampler2D PfmEncodePass;

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
    float thisRaw = texture(PfmEncodePass, vTexCoord)[0];
    vec4 prevYiq = texture(Source, vTexCoord + vec2(offsetPixelsPrev * params.SourceSize.z, -params.SourceSize.w));
    float prevRaw = texture(PfmEncodePass, vTexCoord + vec2(offsetPixelsPrev * params.SourceSize.z, -params.SourceSize.w))[offsetSubpixelsPrev];
    vec4 nextYiq = texture(Source, vTexCoord + vec2(offsetPixelsNext * params.SourceSize.z, params.SourceSize.w));
    float nextRaw = texture(PfmEncodePass, vTexCoord + vec2(offsetPixelsNext * params.SourceSize.z, params.SourceSize.w))[offsetSubpixelsNext];
    //vec4 leftYiq = texture(Source, vTexCoord + vec2(offsetPixelsLeft * params.SourceSize.z, 0));
    //float leftRaw = texture(PfmEncodePass, vTexCoord + vec2(offsetPixelsLeft * params.SourceSize.z, 0))[offsetSubpixelsLeft];
    //vec4 rightYiq = texture(Source, vTexCoord + vec2(offsetPixelsRight * params.SourceSize.z, 0));
    //float rightRaw = texture(PfmEncodePass, vTexCoord + vec2(offsetPixelsRight * params.SourceSize.z, 0))[offsetSubpixelsRight];
    
    if(params.pfm_comb_ymode2 > 1.5 && params.pfm_comb < 2.5) {
        thisYiq.w = prevYiq.w = nextYiq.w = 0;
    } else if(params.pfm_comb_ymode2 > 0.5 && params.pfm_comb < 2.5) {
        thisYiq.w = thisYiq.x;
        prevYiq.w = prevYiq.x;
        nextYiq.w = nextYiq.x;
    } 

    if(params.pfm_comb < 0.5) {
        FragColor = vec4(params.pfm_alt_notch < 0.5 ? thisYiq.xyz : thisYiq.wyz, 1.0);
    } else if(params.pfm_comb < 1.5) {
        // Temporarily assuming that the phase flips 180 degrees each line
        FragColor = vec4(params.pfm_comb_sharpness * (thisRaw - thisYiq.w + prevRaw - prevYiq.w) / 2.0 + thisYiq.w, (thisYiq.yz + prevYiq.yz) / 2.0, 1.0);
    } else if(params.pfm_comb < 2.5) {
        // Temporarily assuming that the phase flips 180 degrees each line
        FragColor = vec4(params.pfm_comb_sharpness * (thisRaw - thisYiq.w + (prevRaw - prevYiq.w + nextRaw - nextYiq.w) / 2.0) / 2.0 + thisYiq.w, (thisYiq.yz + (prevYiq.yz + nextYiq.yz) / 2.0) / 2.0, 1.0);
    } else if(params.pfm_comb < 3.5) {

        // New idea.
        // The only region of frequencies where Y and C don't significantly overlap is the low-frequency Y.
        // That low-frequency region is always treated as Y.
        // The rest of the frequency spectrum is "disputed territory" that might either be Y or C.
        // "Disputed territory" that is in common between lines is treated as Y.
        // "Disputed territory" that is different between lines is treated as C.
        
        // The tricky part of this is comb-filtering Y only within that "disputed territory" without altering the low-frequency region that's already correct.
        // If we just directly comb the consecutive lines, it results in consecutive lines getting unnecessarily blurred together.
        // We don't want consecutive lines to get blurred. We only want to perform comb filtering in the high-frequency part.
        // There's an easy workaround for this.
        // The previous pass already low-passed to get undisputed Y. When we subtract that from non-low-passed Y, we get the "disputed territory" for Y.
        // So, by subtracting each line's lowpassed Y, we get each line's "disputed territory" that we then comb-filter.
        // After comb-filtering the high-frequency information, we add the low-frequency Y back in.

        // The completely wrong way to think about this is how to completely separate luma and chroma.
        // The right way is to make sure that luma has less than 0.01 chroma in it, and that chroma has less than 0.01 luma in it.

        // Step 1: Inside chroma, get rid of as much luma as we can via comb filtering.
        // Step 2: If there's more than 0.01 luma left in our chroma, then desaturate chroma enough to get that luma down to 0.01.
        // Step 3: Inside high-frequency luma, get rid of as much chroma as we can via comb filtering.
        // Step 4: If there's more than 0.01 chroma left in our high-frequency luma, scale down the high-frequency luma enough to get the chroma down to 0.01.
        // Step 5: Add the high-frequency luma to the low-frequency luma of the current line.

        // After a lot of trial and error, and a lot of experimentation, I didn't like that solution.
        // I instead changed to this:

        // Step 1: Compare to see whether the high-frequency region is most similar to the line above, the line below, or the average of both.
        // Step 2: Comb it exactly 50/50.

        // I ultimately decided that combing should always be forced, even when it mathematically looks like it would degrade the image.
        // In reality, the low-passed (or notched) luminance information gets skewed differently by chroma on each line, so leaving this un-combed creates unclear, ridged edges.
        // No matter how low you low-pass or how tightly you notch, this problem won't fix itself.
        // Similarly, there's the problem of what to do with rainbow chroma artifacts that can't be removed by the comb filter.
        // If you force-comb the lines 50/50 all the time, the ridged edges start disappearing, and the chroma artifacts get a little bit blurred out.
        // Even if you can mathematically show that unfilteredY is worse than bothY, prevY, and nextY, combing anyway still visually looks better for these reasons.

        // Swapping in a notch filter only exacerbates the problem caused by sticking to unfiltered or low-passed by causing rippling artifacts to extend outward horizontally.
        // Hence, the idea of swapping in a notch filter at certain times is intentionally skipped.

        // The idea of determining how much high-frequency luma and chroma information is present was flawed too because they're interfering with each other.
        // It seems like the best way is to determine which option has the most similar chroma, and just comb against that option directly.

        // Overall, the results here remind me of my original hardware, even though it's not exactly how it works.
        // Notice how, whenever there's a lone scanline whose neighbors are completely different, the scanline ends up with chroma artifacts.
        // I have seen that same phenomenon on multiple actual comb-filtering CRTs.

        vec2 bmyRmyScaling = vec2(0.492111, 0.877283);

        float thisDiff, prevDiff, nextDiff;

        if(params.pfm_comb_ymode < 1.5) {
            thisDiff = thisRaw - thisYiq.x;
            prevDiff = prevRaw - prevYiq.x;
            nextDiff = nextRaw - nextYiq.x;
        } else {
            thisDiff = thisRaw - thisYiq.w;
            prevDiff = prevRaw - prevYiq.w;
            nextDiff = nextRaw - nextYiq.w;
        }

        //float unfilteredY = thisYiq.w - thisYiq.x;
        float unfilteredY = params.pfm_comb_ymode < 0.5 ? sqrt(dot(pow(abs(thisYiq.yz) * bmyRmyScaling, vec2(2.0)), vec2(1)))
                                                        : abs(thisDiff);
        float unfilteredC = sqrt(dot(pow(abs(thisYiq.yz) * bmyRmyScaling, vec2(2.0)), vec2(1)));//sqrt(dot(pow(abs(thisYiq.yz) * bmyRmyScaling, vec2(2.0)), vec2(1)));

        //float prevY = abs((thisYiq.w - thisYiq.x) - (prevYiq.w - prevYiq.x)) / 2;
        float prevY = params.pfm_comb_ymode < 0.5 ? sqrt(dot(pow(abs(thisYiq.yz - prevYiq.yz) / 2 * bmyRmyScaling, vec2(2.0)), vec2(1)))
                                                        : abs(prevDiff + thisDiff) / 2;
        float prevC = params.pfm_comb_ymode < 10.5 ? sqrt(dot(pow(abs(thisYiq.yz - prevYiq.yz) / 2 * bmyRmyScaling, vec2(2.0)), vec2(1)))
                                                        : abs(prevDiff - thisDiff) / 2;
        //float prevC = sqrt(dot(pow(abs(thisYiq.yz + prevYiq.yz) / 2 * bmyRmyScaling, vec2(2.0)), vec2(1)));

        //float nextY = abs((thisYiq.w - thisYiq.x) - (nextYiq.w - nextYiq.x)) / 2;
        float nextY = params.pfm_comb_ymode < 0.5 ? sqrt(dot(pow(abs(thisYiq.yz - nextYiq.yz) / 2 * bmyRmyScaling, vec2(2.0)), vec2(1)))
                                                        : abs(nextDiff + thisDiff) / 2;
        float nextC = params.pfm_comb_ymode < 10.5 ? sqrt(dot(pow(abs(thisYiq.yz - nextYiq.yz) / 2 * bmyRmyScaling, vec2(2.0)), vec2(1)))
                                                        : abs(nextDiff - thisDiff) / 2;
        //float nextC = sqrt(dot(pow(abs(thisYiq.yz + nextYiq.yz) / 2 * bmyRmyScaling, vec2(2.0)), vec2(1)));

        float bothY = params.pfm_comb_ymode < 0.5 ? sqrt(dot(pow(abs(thisYiq.yz - prevYiq.yz / 2 - nextYiq.yz / 2) / 2 * bmyRmyScaling, vec2(2.0)), vec2(1)))
                                                        : abs((prevDiff + nextDiff) / 2 + thisDiff) / 2;
        float bothC = params.pfm_comb_ymode < 10.5 ? sqrt(dot(pow(abs(thisYiq.yz - prevYiq.yz / 2 - nextYiq.yz / 2) / 2 * bmyRmyScaling, vec2(2.0)), vec2(1)))
                                                        : abs((prevDiff + nextDiff) / 2 - thisDiff) / 2;
        //float bothC = sqrt(dot(pow(abs(thisYiq.yz + prevYiq.yz / 2 + nextYiq.yz / 2) / 2 * bmyRmyScaling, vec2(2.0)), vec2(1)));
/*
        if(params.pfm_comb_ymode2 > 1.5) {
            if(bothC > unfilteredC && prevC > unfilteredC && nextC > unfilteredC) {
                thisRaw = thisYiq.x;
                prevRaw = prevYiq.x;
                nextRaw = nextYiq.x;
            }
        } else if(params.pfm_comb_ymode2 > 0.5) {
            thisYiq.w = thisYiq.x;
            prevYiq.w = prevYiq.x;
            nextYiq.w = nextYiq.x;
        }*/

#define REMOD(chroma) sqrt(dot(pow(abs(chroma) / 2 * bmyRmyScaling, vec2(2.0)), vec2(1)))

        vec3 finalYiq = vec3(0, 0, 0);

        float threshold = 0.1;
        float threshold2 = 0.01;
        float threshold3 = 0.01;
#define WHAT_TO_DO \
        //if(params.pfm_comb_ymode2 > 0.5) { \
        //    thisYiq.w = mix(thisYiq.x, thisYiq.w, min(1, REMOD(finalYiq.yz))); \
        //    prevYiq.w = mix(prevYiq.x, prevYiq.w, REMOD(finalYiq.yz)); \
        //    nextYiq.w = mix(nextYiq.x, nextYiq.w, REMOD(finalYiq.yz)); \
        //} 
            //FragColor = vec4(thisYiq.xyz, 1);\
            //return;  \
            //thisRaw = thisYiq.x; \
            //prevRaw = prevYiq.x; \
            //nextRaw = nextYiq.x; \
            //thisYiq.w = thisYiq.x; \
            //prevYiq.w = prevYiq.x; \
            //nextYiq.w = nextYiq.x;

        if(params.pfm_comb_ymode2 > 1.5) {
            thisYiq.w = prevYiq.w = nextYiq.w = 0;
        } else if(params.pfm_comb_ymode2 > 0.5) {
            thisYiq.w = thisYiq.x;
            prevYiq.w = prevYiq.x;
            nextYiq.w = nextYiq.x;
        } 
        
        if(bothY < prevY && bothY < nextY) {
            /*if(params.pfm_comb_ymode2 > 0.5 && abs((prevYiq.x - prevYiq.w + nextYiq.x - nextYiq.w) / 2 + thisYiq.x - thisYiq.w) / 2 < threshold && bothC > threshold2) {
                WHAT_TO_DO
            }*/
            finalYiq.yz = (thisYiq.yz + (prevYiq.yz + nextYiq.yz) / 2) / 2;
            WHAT_TO_DO
            finalYiq.x += params.pfm_comb_sharpness * ((prevRaw - prevYiq.w + nextRaw - nextYiq.w) / 2 + thisRaw - thisYiq.w) / 2;
        } else if(prevY < nextY) {
            /*if(params.pfm_comb_ymode2 > 0.5 && abs(prevYiq.x - prevYiq.w + thisYiq.x - thisYiq.w) < threshold && prevC > threshold2) {
                WHAT_TO_DO
            }*/
            finalYiq.yz = (thisYiq.yz + prevYiq.yz) / 2;
            WHAT_TO_DO
            finalYiq.x += params.pfm_comb_sharpness * (prevRaw - prevYiq.w + thisRaw - thisYiq.w) / 2;
        } else {
            /*if(params.pfm_comb_ymode2 > 0.5 && abs(nextYiq.x - nextYiq.w + thisYiq.x - thisYiq.w) / 2 < threshold && nextC > threshold2) {
                WHAT_TO_DO
            }*/
            finalYiq.yz = (thisYiq.yz + nextYiq.yz) / 2;
            WHAT_TO_DO
            finalYiq.x += params.pfm_comb_sharpness * (nextRaw - nextYiq.w + thisRaw - thisYiq.w) / 2;
        }

        finalYiq.x += thisYiq.w;

        FragColor = vec4(finalYiq, 1);
    }
}
