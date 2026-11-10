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

This pass performs the following operations (not in order):

* Convert RGB into YIQ (default) or Y B-Y R-Y
* Correct the transfer characteristic (gamma):
    * Electro-optical transfer: power 2.2 (default), sRGB piecewise
    * Opto-electronic transfer: power 2.2 (default), sRGB piecewise, 170M/240M/BT.709
* Correct RGB primaries and reference white:
    * Input primaries and reference white are assumed to be sRGB
    * Output primaries: sRGB, SMPTE C, NTSC 1953 (default)
    * Output white: D65 (default), C, 9300K+8MPCD

Note that many of the above options are not allowed by the video standard.
No effort is made to prevent clipping when converting between different primaries. Please be careful.

In a future version, interlacing will be supported. Currently, only "double-struck" 240p is supported.

When putting this in a shader preset, use the following settings:

Input must use nearest-neighbor interpolation.
Input sizes should be the same as the output sizes.
Framebuffer should use floating point, not integers.

*/

#pragma name PfmInputPass

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;

    float pfm_inputConvert,
          pfm_stdPrims,
          pfm_stdWhite,
          pfm_stdEotf,
          pfm_stdApproxGamma,
          pfm_srgbEotf,
          pfm_modType,
          pfm_fixGenColor,
          pfm_forceInterlace,
          pfm_deflicker;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma parameter pfm_forceInterlace "Force enable interlace: 0:Off 1:On" 0 0 1 1
#pragma parameter pfm_deflicker "Deflicker (only when interlacing)" 0 0 1 1
#pragma parameter pfm_deinterlaceMethod "Deinterlace method: 0: Weave 1: Average 2: Bob 3: Smoothed Bob" 0 0 3 1
#pragma parameter pfm_inputConvert "Convert input sRGB into video standard (0:Off 1:On)" 0 0 1 1
#pragma parameter pfm_stdPrims "Primaries 0: sRGB 1: SMPTE C (DVD) 2: NTSC 1953 (Broadcast/VHS)" 2 0 2 1
#pragma parameter pfm_stdWhite "White -1: C 0: D65 1: D93 (Japan)" 0 -1 1 1
#pragma parameter pfm_stdEotf "OETF 0:Power 1:sRGB 2:170M/BT.709" 0 0 2 1
#pragma parameter pfm_stdApproxGamma "OETF Power Gamma" 2.2 1.1 3.0 0.1
#pragma parameter pfm_srgbEotf "Input sRGB EOTF: 0: Power 2.2 1: Piecewise" 0 0 1 1
#pragma parameter pfm_modType "Encoder lowpass -1:Off 0:Old IQ 1:Equiband B-Y R-Y 2:Narrowband" 1 -1 2 1
#pragma parameter pfm_fixGenColor "Gen/MD Palette (for Gen Plus GX and PicoDrive, but not BlastEm)" 0 0 1 1

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

const mat3 primariesLookup[] = {
    mat3(
        // NTSC 1953 primaries
        0.67, 0.33, 1-0.67-0.33,
        0.21, 0.71, 1-0.21-0.71,
        0.14, 0.08, 1-0.14-0.08
    ),
    mat3(
        // SMPTE-C primaries, used in SMPTE-170M and SMPTE-240M
        0.630, 0.340, 1-0.630-0.340,
        0.310, 0.595, 1-0.310-0.595,
        0.155, 0.070, 1-0.155-0.070
    ),
    mat3(
        // EBU primaries https://tech.ebu.ch/docs/tech/tech3213.pdf
        0.64, 0.33, 1-0.64-0.33,
        0.29, 0.60, 1-0.29-0.60,
        0.15, 0.06, 1-0.15-0.06
    )
};

const vec3 whiteLookup[] = {
    vec3(0.31, 0.316, 1-0.31-0.316) / 0.316, // Illuminant C
    vec3(0.3127, 0.3290, 1-0.3127-0.3290) / 0.3290, // Illuminant D65
    vec3(0.283, 0.298, 1-0.283-0.298) / 0.298, // Illuminant 9300K+8MPCD
    vec3(0.281, 0.311, 1-0.281-0.311) / 0.311 // Illuminant 9300K+27MPCD
};

const mat3 srgbPrimaries = mat3(
   0.64, 0.33, 1-0.64-0.33,
   0.30, 0.60, 1-0.30-0.60,
   0.15, 0.06, 1-0.15-0.06
);

vec3 srgbWhite = vec3(0.3127, 0.3290, 1-0.3127-0.3290) / 0.3290; // Illuminant D65

int decoderStdPrims[] = {
    1, // US SMPTE-C
    0, // US Standard
    0, // US Consumer 9300K (Toshiba 1985)
    0, // US Consumer 7500K (RCA 1989)
    0, // US Consumer 8700K (Average)
    0, // JP Standard
    0, // JP Consumer 9300K
    0, // JP Consumer 12500k
    0, // JP Guessed 8500K
    0, // jp guessed 14000k
    0, // US adapted 9300K 
    0, // US undapted 9300K 
    0, // US undapted 9300K alt
};

vec3 decoderStdWhite[] = {
    whiteLookup[1], // US SMPTE-C
    whiteLookup[0], // US Standard
    whiteLookup[0], // US Consumer 9300K
    whiteLookup[0], // US Consumer 7500K
    whiteLookup[0], // US Consumer 8700K
    whiteLookup[2], // JP Standard
    whiteLookup[2], // JP consumer 9300k
    whiteLookup[2], // JP consumer 12500k
    whiteLookup[2], // jp guessed 8500k
    whiteLookup[2], // jp guessed 14000k
    whiteLookup[1], // US Adapted 9300K
    whiteLookup[1], // US undapted 9300K
    whiteLookup[0], // US undapted 9300K alt
};

vec3 decoderDstWhite[] = {
    whiteLookup[1], // US SMPTE-C
    whiteLookup[0], // US Standard
    whiteLookup[3] * 0.945, // us consumer 9300k
    vec3(0.30033, 0.31026, 1 - 0.30033 - 0.31026) / 0.31026 * 1.017, // us consumer 7500K
    vec3(0.28916, 0.30393, 1 - 0.28916 - 0.30393) / 0.30393, // US Consumer 8700K (From Donfrio's paper on CRT white balances. A few sampled CRTs were clustered around this point.)
    whiteLookup[2], // JP Standard
    whiteLookup[3], // JP consumer 9300k
    vec3(0.265, 0.279,1-.265-.279)/.279 * 0.993, // JP consumer 12500k. Note that 12500k is only a CCT, whereas this point is the reverse-engineered xy coordinate from the Sony CXA1464AS with 2.2 gamma and Sony Trinitron phosphors.
    vec3(0.29076,0.30573,1-0.29076-0.30573)/0.30573, // JP guessed 8500k (Daylight CCT. According to the Dogway's Grading Shader (slang) thread on RetroArch, there are reports of Japan CRTs from 8200K to 8800K.)
    vec3(0.26066, 0.27436, 1-0.26066-0.27436)/0.27436, // JP guessed 14000k (Sampled from AMERICAN Panasonic CT-36D30B from 2000, with white balance set to "Cool")
    whiteLookup[3], // us adapted 9300k
    whiteLookup[3], // us unadapted 9300k
    whiteLookup[3], // us unadapted 9300k alt
};

vec3 decoderInputs[][3] = {
    {vec3(0.5, 0.35, 1-0.5-0.35)/0.35, vec3(0.4, 0.45, 1-0.4-0.45)/0.45, vec3(0)}, // US SMPTE-C
    {vec3(0.5, 0.35, 1-0.5-0.35)/0.35, vec3(0.4, 0.45, 1-0.4-0.45)/0.45, vec3(0.37, 0.22,1-0.37-0.22)/0.22}, // US Standard
    {vec3(0.4008,0.46,1-0.4008-0.46)/0.46, vec3(0.48,0.34,1-0.48-0.34)/0.34, vec3(0)}, // US Consumer 9300K
    {vec3(0.472,0.364,1-.472-.364)/.364,vec3(.3508,.414,1-.3508-.414)/.414,vec3(0)}, // US Consumer 7500K
    {vec3(0.476,0.352,1-.476-.352)/.352,vec3(.3758,.437,1-.3758-.437)/.437,vec3(0)}, // US Consumer 8700K
    {vec3(0.5, 0.35, 1-0.5-0.35)/0.35, vec3(0.4, 0.45, 1-0.4-0.45)/0.45, vec3(0.37, 0.22,1-0.37-0.22)/0.22}, // JP Standard
    {vec3(0.476,0.352,1-.476-.352)/.352,vec3(.3758,.437,1-.3758-.437)/.437,vec3(0)}, // JP consumer 9300k
    {vec3(.464,.372,1-.464-.372)/.372,vec3(.416,.453,1-.416-.453)/.453,vec3(0)}, // JP consumer 12500k (cxa1464as)
    {vec3(0.476,0.352,1-.476-.352)/.352,vec3(.3758,.437,1-.3758-.437)/.437,vec3(0)}, // JP guessed 8500k
    {vec3(0.476,0.352,1-.476-.352)/.352,vec3(.3758,.437,1-.3758-.437)/.437,vec3(0)}, // JP guessed 14000k
    {vec3(0.5, 0.35, 1-0.5-0.35)/0.35, vec3(0.4, 0.45, 1-0.4-0.45)/0.45, vec3(0.37, 0.22,1-0.37-0.22)/0.22}, // US adapted 9300K
    {vec3(0.476,0.352,1-.476-.352)/.352,vec3(.3758,.437,1-.3758-.437)/.437,vec3(0)}, // US unadapted 9300k
    {vec3(0.476,0.352,1-.476-.352)/.352,vec3(.3758,.437,1-.3758-.437)/.437,vec3(0)}, // US unadapted 9300k alt
};

vec3 decoderOutputs[][3] = {
    {decoderInputs[0][0], decoderInputs[0][1], decoderInputs[0][2]}, // US SMPTE C
    {decoderInputs[1][0], decoderInputs[1][1], decoderInputs[1][2]}, // US Standard
    {decoderInputs[2][0]*1.021, decoderInputs[2][1], decoderInputs[2][2]}, // US Consumer 9300K
    {decoderInputs[3][0]*1.021, decoderInputs[3][1], decoderInputs[3][2]}, // US Consumer 7500K
    {decoderInputs[4][0], decoderInputs[4][1], decoderInputs[4][2]}, // US Consumer 8700K
    {decoderInputs[5][0], decoderInputs[5][1], decoderInputs[5][2]}, // JP Standard
    {decoderInputs[9][0], decoderInputs[9][1], decoderInputs[9][2]}, // JP guessed 9300k
    {vec3(.464,.372,1-.464-.372)/.372*1.044,vec3(.416,.453,1-.416-.453)/.453*1.018,vec3(0)}, // JP consumer 12500k (cxa1464as)
    {decoderInputs[9][0], decoderInputs[9][1], decoderInputs[9][2]}, // JP guessed 8500k
    {decoderInputs[9][0], decoderInputs[9][1], decoderInputs[9][2]}, // JP guessed 14000k
    {decoderInputs[1][0], decoderInputs[1][1], decoderInputs[1][2]}, // US adapted 9300K
    {decoderInputs[4][0], decoderInputs[4][1], decoderInputs[4][2]}, // US unadapted 9300k
    {decoderInputs[4][0], decoderInputs[4][1], decoderInputs[4][2]}, // US unadapted 9300k alt
};

// Type 0: Change white point, don't adapt other points.
// Type 1: Change white point, adapt via CAT16 matrix

int adaptType[] = {
    0, // US SMPTE C
    0, // US Standard
    0, // US 9300k
    0, // US 7500K
    0, // US 8700k
    0, // jp standard
    0, // jp 9300k+27mpcd
    0, // jp 12500k
    0, // jp unadapted 8500k
    0, // jp unadapted 14000k
    1, // US Adapted 9300K+27MPCD
    0, // US Undapted 9300K+27MPCD
    0, // US Undapted 9300K+27MPCD alt
};

mat3 rgbToXyzMatrix(mat3 prims, vec3 white) {
   vec3 wrongBalance = inverse(prims) * white;
   return prims * mat3(wrongBalance[0], 0, 0,
                       0, wrongBalance[1], 0,
                       0, 0, wrongBalance[2]);
}

mat3 xyzToRgbMatrix(mat3 prims, vec3 white) {
   return inverse(rgbToXyzMatrix(prims, white));
}

mat3 catMatrix(vec3 srcWhite, vec3 dstWhite, int catType) {
    // http://www.brucelindbloom.com/index.html?Eqn_ChromAdapt.html
    // I am omitting methods that are too old (such as XYZ scaling) or too new (such as CAT16).
    mat3 lmsMat;
    if(catType == 0) {
        // Von Kries
        lmsMat = transpose(mat3(
            0.4002400,  0.7076000, -0.0808100,
            -0.2263000,  1.1653200,  0.0457000,
            0.0000000,  0.0000000,  0.9182200
        ));
    } else if(catType == 1) {
        // Bradford
        lmsMat = transpose(mat3(
            0.8951000,  0.2664000, -0.1614000,
            -0.7502000,  1.7135000,  0.0367000,
            0.0389000, -0.0685000,  1.0296000
        ));
    } else {
        // CAT16
        // Li Changjun, et al., A Revision of CIECAM02 and its CAT and UCS (2016) (https://library.imaging.org/admin/apis/public/api/ist/website/downloadArticle/cic/24/1/art00035)
        // https://github.com/LeaVerou/color.js/blob/f505c1b5230e1eabf5893f6a8eefb335936e55e0/src/CATs.js
        lmsMat = transpose(mat3(
            0.401288, 0.650173, -0.051461,
            -0.250268, 1.204414, 0.045854,
            -0.002079, 0.048952, 0.953127
        ));
    }
    vec3 userLms = lmsMat * dstWhite;
    vec3 bcstLms = lmsMat * srcWhite;
    mat3 cat = inverse(lmsMat) * mat3(
        userLms[0] / bcstLms[0], 0, 0,
        0, userLms[1] / bcstLms[1], 0,
        0, 0, userLms[2] / bcstLms[2]
    ) * lmsMat;
    return cat;
}

float srgbToLinear(float srgb) {
    const float U = 0.04045,
                A = 12.92,
                C = 0.055,
                G = 2.4;
    
    float linear;
    if(srgb <= U) {
        linear = srgb / A;
    } else {
        linear = pow((srgb + C) / (1 + C), G);
    }
    return linear;
}

float linearToSrgb(float linear) {
    const float V = 0.0031308,
                A = 12.92,
                C = 0.055,
                G = 2.4;
    
    float srgb;
    if(linear <= V) {
        srgb = A * linear;
    } else {
        srgb = (1 + C) * pow(linear, 1.0 / G) - C;
    }
    
    return srgb;
}

vec3 srgbToLinear(vec3 srgb) {
   for(int i = 0; i < 3; i++) {
      srgb[i] = srgbToLinear(srgb[i]);
   }
   return srgb;
}

vec3 linearToSrgb(vec3 srgb) {
   for(int i = 0; i < 3; i++) {
      srgb[i] = linearToSrgb(srgb[i]);
   }
   return srgb;
}

// Based on BT.1886.
// Both the Annex 1 equation and the Appendix 1 equation are supported.
// Annex 1 is a simple 2.4 power law equation with adjustable brightness. This is established as the standard.
// Appendix 1 is meant to more precisely match a CRT's response. It is not the standard, but it's provided for cases where a more precise match is needed.
// approxGamma must be from 1.1 to 3.0. If it is not, it will be clamped.
// This is meant to represent the CRT's real output. Changing luminance directly will cause a change in chromaticity.
// This should not be used in cases where we isolate average chromaticity from luminance. Just use approxGamma straight-up instead.
float bt1886(float prime, float approxGamma, bool use24) {

   approxGamma = clamp(approxGamma, 1.1, 3.0); // Enforce input domain

   // 2.4 power law lookup table for b.
   // Determined by regression in Desmos - https://www.desmos.com/calculator/n5qvkdri2e
   // Note that the 2.4 gamma curve is of a form similar to a((x+b)^2.4-(b)^2.4).
   // In other words, when matching, we cut off the black lift, and we freely adjust b to approximate *any multiple of* x^approxGamma.
   // The match is optimized in linear space, not L* or anything like that.
   
   // I don't know, but Desmos might or might not be rearranging the equation internally, and if it is, it might or might not be undesirable.
   // For instance, power-law least-squares regressions are traditionally done by taking the logarithms of both the inputs and outputs and performing a linear regression on that.
   
   const float lookupB24[] = {
      3.94512, // gamma ~1.1
      1.8496,
      1.14748,
      0.793952,
      0.579995,
      0.435891,
      0.331736,
      0.252552,
      0.19, // gamma ~1.9
      0.139054,
      0.09649,
      0.060124, // gamma ~2.2
      0.0283832,
      0, // gamma = 2.4 perfectly
      -0.026012,
      -0.0521574,
      -0.076701,
      -0.1003,
      -0.123008,
      -0.144874 // gamma ~3.0
   };

   // BT.1886 b regression - https://www.desmos.com/calculator/6howwe9l4n
   // Same idea. To support gammas higher than 2.6, I added a max(0) to the equation to prevent negative results.
   const float lookupBCRT[] = {
      2.6825,
      1.61812,
      1.12401,
      0.836667,
      0.647482,
      0.512607,
      0.410931,
      0.33102,
      0.266131,
      0.212021,
      0.165876,
      0.125743,
      0.0902154,
      0.0582329,
      0.0289621,
      0.00170671,
      -0.0240737,
      -0.0485584,
      -0.0718382,
      -0.0939854
   };

   const float PL_EPSILON = 0.0001; // approxGamma's precision is +-0.0001. Gammas are typically only 2 significant figures.
   const float PL_MIN = 1.1;
   const float PL_MAX = 3.0;
   const float PL_STEP = 0.1; // Must divide (PL_MAX - PL_MIN) to a whole number
   const int lookupBLength = int((PL_MAX - PL_MIN) / PL_STEP + 1.5);

   float scaledIndexF = (approxGamma - PL_MIN) / (PL_STEP);
   int lowerIndex = int(0.5 + floor(scaledIndexF + PL_EPSILON));
   int higherIndex = int(0.5 + ceil(scaledIndexF - PL_EPSILON));
   
   #define LOOKUPB (use24 ? lookupB24 : lookupBCRT)
   float b;
   if(lowerIndex == higherIndex) {
      b = LOOKUPB[lowerIndex];
   } else {
      // Linearly interpolate the hardcoded points.
      b = mix(LOOKUPB[lowerIndex], LOOKUPB[higherIndex], scaledIndexF - lowerIndex);
   }
   #undef LOOKUPB

   float resultUnscaled;
   float blackUnscaled; // This is for removing the black lift.
   float whiteUnscaled; // This is for the 'a' (Annex 1) or 'k' (Appendix 1) constant.
   if(use24) {
      resultUnscaled = prime + b <= 0 ? 0 : pow(prime + b, 2.4);
      blackUnscaled = b <= 0 ? 0 : pow(b, 2.4);
      whiteUnscaled = pow(1 + b, 2.4);
   } else {
      if(prime <= 0) {
         resultUnscaled = 0; // This will still be max'd to 0 when we remove the black lift.
      } else if(prime < 0.35) {
         resultUnscaled = pow(0.35 + b, 2.6 - 3.0) * pow(prime + b, 3.0);
      } else {
         resultUnscaled = pow(prime + b, 2.6);
      }
      blackUnscaled = pow(0.35 + b, 2.6 - 3.0) * pow(b, 3.0);
      whiteUnscaled = pow(1 + b, 2.6);
   }

   // Remove black lift, scale up to 1.0, and max() any negative results up to 0.
   return max((resultUnscaled - blackUnscaled) / (whiteUnscaled - blackUnscaled), 0);
}

vec3 bt1886(vec3 prime, float approxGamma, bool use24) {
   for(int i = 0; i < 3; i++) {
      prime[i] = bt1886(prime[i], approxGamma, use24);
   }
   return prime;
}

vec3 fixGenColor(vec3 src) {
    
    // Code in BlastEm looks like this:
//    static uint8_t levels[] = {0, 27, 49, 71, 87, 103, 119, 130, 146, 157, 174, 190, 206, 228, 255};
//    b = levels[(color >> 8) & 0xE];
//	  g = levels[(color >> 4) & 0xE];
//	  r = levels[color & 0xE];

    // whereas Genesis Plus GX has this:
//    /* 8:8:8 RGB */
//#elif defined(USE_32BPP_RENDERING)
//#define MAKE_PIXEL(r,g,b) ((0xff << 24) | (r) << 20 | (r) << 16 | (g) << 12 | (g)  << 8 | (b) << 4 | (b))
//#endif
//
///* Initialize Mode 5 pixel color look-up tables */
//  for (i = 0; i < 0x200; i++)
//  {
//    /* CRAM 9-bit value (BBBGGGRRR) */
//    r = (i >> 0) & 7;
//    g = (i >> 3) & 7;
//    b = (i >> 6) & 7;
//
//    /* Convert to output pixel format */
//    pixel_lut[0][i] = MAKE_PIXEL(r,g,b);
//    pixel_lut[1][i] = MAKE_PIXEL(r<<1,g<<1,b<<1);
//    pixel_lut[2][i] = MAKE_PIXEL(r+7,g+7,b+7);
//  }

    float levels[] = {0, 27, 49, 71, 87, 103, 119, 130, 146, 157, 174, 190, 206, 228, 255};
    for(int i = 0; i < 3; i++) {
        src[i] = levels[int(min(src[i] * 16 + 0.5, 14.5))] / 255.0;
    }
    return src;

    // Old code from Dogway's Grading Shader (grade.slang) which does not work as of August 2024

//   float lo, hi;
//   for(int i = 0; i < 5; i++) {
//      float cont = 2.578419881;
//      float pivot = 0.520674;
//      float color = (i < 3 ? src[i] : i - 3.0);
//
//      cont = pow(cont - 1., 3.);
//
//      float knee  = 1. / (1. + exp (cont *  pivot));
//      float shldr = 1. / (1. + exp (cont * (pivot - 1.)));
//      
//      float res = pivot - log(1. / (color * (shldr - knee) + knee) - 1.) / cont;
//      if(i < 3)
//         src[i] = res;
//      else if(i == 3)
//         lo = res;
//      else
//         hi = res;
//   }
//   return (src - lo) / (hi - lo);
}

void main() {

///////////////////////////
// Standard constants
///////////////////////////

    // SMPTE 170M standard conversions from RGB to YIQ and Y B-Y R-Y
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
    
    bool useIQ = params.pfm_modType > -0.5 && params.pfm_modType < 0.5;
    mat3 rgbToYC = useIQ ? rgbToYiq : rgbToYBmyRmy;

    vec3 inputRgb;
#ifndef COLOR_ONLY
    if(params.SourceSize.y > 300 || params.pfm_forceInterlace > 0.5) {
        // Interlace
        float resFix = params.OutputSize.y > 300 && params.pfm_forceInterlace < 0.5 ? 2.0 : 1.0;
        inputRgb = texture(Source, vec2(vTexCoord.x, vTexCoord.y * resFix + params.SourceSize.w * (params.FrameCount % 2 - 0.5))).rgb;
        if(params.pfm_deflicker > 0.5) {
            vec3 otherRgb = texture(Source, vec2(vTexCoord.x, vTexCoord.y * resFix + params.SourceSize.w * (params.FrameCount % 2 + 0.5))).rgb;
            inputRgb = pow(
                (pow(max(inputRgb, vec3(0)), vec3(2.2)) +
                pow(max(otherRgb, vec3(0)), vec3(2.2))) / 2.0,
                vec3(1.0 / 2.2)
            );
        }
    } else
#endif
    {
        inputRgb = texture(Source, vTexCoord).rgb;
    }

    if(params.pfm_fixGenColor > 0.5) {
        inputRgb = fixGenColor(inputRgb);
    }

    if(params.pfm_inputConvert > 0.5) {
        if(params.pfm_srgbEotf < 0.5) {
            inputRgb = pow(inputRgb, vec3(2.2));
        } else {
            inputRgb = srgbToLinear(inputRgb);
        }
        inputRgb = xyzToRgbMatrix(params.pfm_stdPrims < 0.5 ? srgbPrimaries : primariesLookup[int(2.5 - params.pfm_stdPrims)],
                                  params.pfm_stdWhite < -0.5 ? whiteLookup[0] : params.pfm_stdWhite < 0.5 ? srgbWhite : whiteLookup[2]) * rgbToXyzMatrix(srgbPrimaries, srgbWhite) * inputRgb;
        vec3 signs = sign(inputRgb);
        inputRgb = abs(inputRgb);
        if(params.pfm_stdEotf < 0.5) {
            inputRgb = pow(inputRgb, vec3(1.0 / params.pfm_stdApproxGamma));
        } else if(params.pfm_stdEotf < 1.5) {
            inputRgb = linearToSrgb(inputRgb);
        } else {
            for(int i = 0; i < 3; i++) {
                if(inputRgb[i] < 0.018) {
                    inputRgb[i] = 4.5 * inputRgb[i];
                } else {
                    inputRgb[i] = 1.099 * pow(inputRgb[i], 0.45) - 0.099;
                }
            }
        }
        inputRgb *= signs;
    }

    FragColor = vec4(rgbToYC * inputRgb, 1.0);
}
