#version 450

/*

Patchy68k Fast Multipass - Simulation of analog video signal artifacts and color correction
Copyright (C) 2025 Patchy68k/PlainOldPants

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>. 

*/

/*

Prepend any of the video signal shaders to a CRT shader, set pf_hdr_enable = 2.0, and append this after the CRT shader.
This will allow you to simulate CRT colors and still have an acceptable CRT mask.

*/

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
          pf_console,
          pf_srgb_eotf,
          pf_contrast,
          pf_gamma,
          pf_color,
          pf_tint,
          pf_videostd,
          pf_clipping,
          pf_clipping_clean,
          pf_randomize_color,
          pf_randomize_tint,
          pfm_forceInterlace;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;

    float pf_gammatype;
    float pf_videostd_rp167;
    float pfm_nesRowSkew,
          pf_hdr_enable,
          pf_hdr_gamut,
          pf_hdr_crt_enable,
          pf_hdr_crt;
} global;

#pragma parameter pfm_nesRowSkew "NES row skew (deg.) (usually about 4.5, sometimes 2.5)" 4.5 -30 30 0.25
#pragma parameter pfm_forceInterlace "Force enable interlace: 0:Off 1:On" 0 0 1 1
#pragma parameter pfm_inputConvert "Convert input sRGB into video standard (0:Off 1:On)" 0 0 1 1
#pragma parameter pfm_stdPrims "Primaries 0: sRGB 1: SMPTE C (DVD) 2: NTSC 1953 (Broadcast/VHS)" 2 0 2 1
#pragma parameter pfm_stdWhite "White -1: C 0: D65 1: D93 (Japan)" 0 -1 1 1
#pragma parameter pfm_stdEotf "OETF 0:Power 1:sRGB 2:170M/BT.709" 0 0 2 1
#pragma parameter pfm_stdApproxGamma "OETF Power Gamma" 2.2 1.1 3.0 0.1
#pragma parameter pfm_srgbEotf "Input sRGB EOTF: 0: Power 2.2 1: Piecewise" 0 0 1 1
#pragma parameter pf_srgb_eotf "Your display sRGB EOTF: 0:Piecewise 1:2.2 2:Linear" 1 0 2 1
#pragma parameter pf_contrast "Contrast (Set 0 to perfectly stop clamping. CRTs rarely clamp.)" 0.0 0 1 0.02
#pragma parameter pf_gamma "Approx. gamma / Brightness (recommend 2.2)" 2.2 1.1 3.0 0.025
#pragma parameter pf_color "Color (Saturation)" 1 0 3 0.01
#pragma parameter pf_tint "Tint (Hue Rotation)" 0 -360 360 0.5
#pragma parameter pf_videostd "Video decoder/region (see list below)" 6 0 20 1
#pragma parameter pf_videostd_rp167 "Default Tint/Col 0: Correct 1: Wrong SMPTE RP167 Color Bar sync" 0 0 1 1
#pragma parameter pf_clipping "Clip overbrightened: 0:Desaturate 1:Darken 2:Clamp 3:Expose" 2 0 3 1
#pragma parameter pf_clipping_clean "(Hack) Flatten out over-brightened/darkened colors (not on NES)" 0 0 1 0.1
#pragma parameter pf_gammatype "CRT gamma mode: 0:Power 1:BT.1886 Piecewise 2:BT.1886 2.4 Power" 0 0 2 1
#pragma parameter pf_randomize_color "Randomize color (0=Off)" 0 -10000 10000 1
#pragma parameter pf_randomize_tint "Randomize tint (0=Off)" 0 -10000 10000 1
#pragma parameter pf_hdr_enable "HDR mode: 0:Off 1:Solo 2:Appendable" 0 0 2 1
#pragma parameter pf_hdr_gamut "HDR gamut: 0:Display P3 1:Rec.2020 2:Adobe 3:sRGB(SDR)" 0 0 3 1
#pragma parameter pf_hdr_crt_enable "HDR, real CRT simulation: 0:Off 1:On" 1 0 1 1
#pragma parameter pf_hdr_crt "HDR real CRT (see second list)" 0 0 4 1
#pragma parameter pf_comment "=== LIST OF VIDEO DECODERS ===" 0 0 0 1
#pragma parameter pf_comment0 "0: Dummy (Raw NTSC RGB, like FirebrandX's Composite Direct)" 0 0 0 1
#pragma parameter pf_comment1 "1: US SMPTE C (Basically ONLY professional CRTs ONLY SINCE '94)" 0 0 0 1
#pragma parameter pf_comment2 "2: US Standard C (Mostly professional CRTs, rarely consumers.)" 0 0 0 1
#pragma parameter pf_comment3 "3: US Consumer 9300K (From 1985 Toshiba CF2005, like CXA2025AS)" 0 0 0 1
#pragma parameter pf_comment4 "4: US Consumer 8000K (From 1989 RCA E13169GM, lighter consumer)" 0 0 0 1
//#pragma parameter pf_comment5 "5: US Guessed 8700K (Average of 18 TV white balances in 1993)" 0 0 0 1
#pragma parameter pf_comment6 "6: JP Standard D93 (Professional CRTs)" 0 0 0 1
#pragma parameter pf_comment7 "7: JP Guessed 9300K (No evidence, but probable)" 0 0 0 1
//#pragma parameter pf_comment8 "8: JP Consumer 12500K (Not so sure anymore. Maybe CXA1464AS.)" 0 0 0 1
//#pragma parameter pf_comment9 "9: JP Guessed 8500K (No evidence that this exists)" 0 0 0 1
//#pragma parameter pf_comment10 "10: JP Guessed 14000K (No evidence, but alleged by ranmori)" 0 0 0 1
//#pragma parameter pf_comment11 "WARNING! DECODERS BELOW THIS LINE ARE EVEN MORE EXPERIMENTAL!" 0 0 0 1
//#pragma parameter pf_comment12 "11: US Adapted 9300K for D65 bcst (VERY UNLIKELY TO EVER EXIST)" 0 0 0 1
//#pragma parameter pf_comment13 "12: US Consumer 9300K for D65 broadcasts (Barely any evidence)" 0 0 0 1
//#pragma parameter pf_comment14 "13: US Consumer 9300K Fixed Y (Probably CXA2025AS & CXA1465AS)" 0 0 0 1
#pragma parameter pf_comment15 "14: US Standard D65 (Maybe professional CRTs, only since 1994)" 0 0 0 1
#pragma parameter pf_comment16 "15: RGB D93 (Many PC monitors. Also since-1994 professional.)" 0 0 0 1
#pragma parameter pf_comment17 "16: RGB 9300K+27MPCD (Many PC monitors. NEVER professional.)" 0 0 0 1
#pragma parameter pf_comment18 "17: RGB D65 (Placed here for convenience; same as decoder 0.)" 0 0 0 1
#pragma parameter pf_comment19 "18: RGB C (Unlikely, but possible.)" 0 0 0 1
#pragma parameter pf_comment20 "19: US Consumer D65 (from US Standard C. Barely any evidence.)" 0 0 0 1
//#pragma parameter pf_comment21 "20: US Alternate Standard C" 0 0 0 1
//#pragma parameter pf_comment22 "(PAL mode is coming soon)" 0 0 0 1
//#pragma parameter pf_comment23 "(A consumer PAL decoder is coming soon)" 0 0 0 1
#pragma parameter pf_comment24 "(My CRT from 2000 is coming soon)" 0 0 0 1
#pragma parameter pf_disclaimer1 "Disclaimer: The TVs and decoder chips mentioned above are not" 0 0 0 1
#pragma parameter pf_disclaimer2 "truly emulated in this shader. Instead, I have tried my best to" 0 0 0 1
#pragma parameter pf_disclaimer3 "reverse-engineer them with their original phosphors, and" 0 0 0 1
#pragma parameter pf_disclaimer4 "re-create them with sRGB primaries instead of those phosphors." 0 0 0 1
#pragma parameter pf_disclaimer5 "Some are only based on standards, without a real TV as proof." 0 0 0 1
#pragma parameter pf_known "=== LIST OF REAL CRTS === " 0 0 0 1
#pragma parameter pf_known0 "0: 1997 Sony KV-27S22, JP axis mode" 0 0 0 1
#pragma parameter pf_known1 "1: 1997 Sony KV-27S22, US axis mode" 0 0 0 1
#pragma parameter pf_known2 "2: 1985 Toshiba CF2005" 0 0 0 1
#pragma parameter pf_known3 "3: 1989 RCA E13169GM-F02" 0 0 0 1
#pragma parameter pf_known4 "4: 2000 Panasonic CT-36D30B" 0 0 0 1
#pragma parameter pf_known5 "Disclaimer: CRT color data might not be completely accurate" 0 0 0 1

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

const mat3 srgbPrimaries = mat3(
   0.64, 0.33, 1-0.64-0.33,
   0.30, 0.60, 1-0.30-0.60,
   0.15, 0.06, 1-0.15-0.06
);

vec3 srgbWhite = vec3(0.3127, 0.3290, 1-0.3127-0.3290) / 0.3290; // Illuminant D65

const mat3 hdrPrimaries[] = {
    mat3( // Display P3
        0.680, 0.320, 1 - 0.680 - 0.320,
        0.265, 0.690, 1 - 0.265 - 0.690,
        0.150, 0.060, 1 - 0.150 - 0.060
    ),
    mat3( // Rec. 2020
        0.708, 0.292, 1 - 0.708 - 0.292,
        0.170, 0.797, 1 - 0.170 - 0.797,
        0.131, 0.046, 1 - 0.131 - 0.046
    ),
    mat3( // Adobe
        0.64, 0.33, 1 - 0.64 - 0.33,
        0.21, 0.71, 1 - 0.21 - 0.71,
        0.15, 0.06, 1 - 0.15 - 0.06
    ),
    mat3( // sRGB, not HDR
        0.64, 0.33, 1-0.64-0.33,
        0.30, 0.60, 1-0.30-0.60,
        0.15, 0.06, 1-0.15-0.06
    )
};

const mat3 crtPrimaries[] = {
    mat3( // 6 - P22 phosphors, Trinitron
        0.621,0.34,0.039,
        0.281,0.606,0.113,
        0.152,0.067,0.781
    ),
    mat3( // 6 - P22 phosphors, Trinitron
        0.621,0.34,0.039,
        0.281,0.606,0.113,
        0.152,0.067,0.781
    ),
    mat3( // 19 - P22 phosphors, Toshiba Blackstripe CF2005, Patchy68k measurement
        0.642,0.339,0.019,
        0.301,0.601,0.098,
        0.144,0.071,0.785
    ),
    mat3( // 18 - P22 phosphors, RCA ColorTrak Remote E13169GM, Patchy68k measurement
        0.623492333,0.343975233,0.032532434,
        0.312266967,0.590305267,0.097427766,
        0.153586233,0.064531667,0.7818821
    ),
    mat3( // 20 - P22 phosphors, Panasonic CT-36D30B, Patchy68k measurement
        0.651212890899489, 0.327170850978215, 1 - 0.651212890899489 - 0.327170850978215,
        0.311678021451133, 0.607717178761663, 1 - 0.311678021451133 - 0.607717178761663,
        0.15033614521611, 0.0665766255634717, 1 - 0.15033614521611 - 0.0665766255634717
    )
};

mat3 getCRTPrimaries() {
    if(global.pf_hdr_enable < 0.5 || global.pf_hdr_crt_enable < 0.5) {
        return srgbPrimaries;
    } else {
        return crtPrimaries[int(global.pf_hdr_crt + 0.5)];
    }
}

mat3 rgbToXyzMatrix(mat3 prims, vec3 white) {
   vec3 wrongBalance = inverse(prims) * white;
   return prims * mat3(wrongBalance[0], 0, 0,
                       0, wrongBalance[1], 0,
                       0, 0, wrongBalance[2]);
}

mat3 xyzToRgbMatrix(mat3 prims, vec3 white) {
   return inverse(rgbToXyzMatrix(prims, white));
}

float srgbToLinearEncode(float srgb) {
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

float linearToSrgbEncode(float linear) {
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

vec3 srgbToLinearEncode(vec3 srgb) {
   for(int i = 0; i < 3; i++) {
      srgb[i] = srgbToLinearEncode(srgb[i]);
   }
   return srgb;
}

vec3 linearToSrgbEncode(vec3 srgb) {
   for(int i = 0; i < 3; i++) {
      srgb[i] = linearToSrgbEncode(srgb[i]);
   }
   return srgb;
}

float srgbToLinear(float srgb) {
   if(params.pf_srgb_eotf > 0.5 && params.pf_srgb_eotf < 1.5) {
      return pow(max(srgb, 0), 2.2);
   } else if(params.pf_srgb_eotf > 1.5) {
      return srgb;
   } else {
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
}

float linearToSrgb(float linear) {
   if(params.pf_srgb_eotf > 0.5 && params.pf_srgb_eotf < 1.5) {
      return pow(max(linear, 0), 1 / 2.2);
   } else if(params.pf_srgb_eotf > 1.5) {
      return linear;
   } else {
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

void main() {
    vec3 crtColor = texture(Source, vTexCoord).rgb;
    mat3 finalHdrMat = xyzToRgbMatrix(hdrPrimaries[int(global.pf_hdr_gamut + 0.5)], srgbWhite) * rgbToXyzMatrix(getCRTPrimaries(), srgbWhite);
    vec3 finalColor = linearToSrgb(finalHdrMat * srgbToLinear(crtColor));
    FragColor = vec4(finalColor, 1.0);
}
