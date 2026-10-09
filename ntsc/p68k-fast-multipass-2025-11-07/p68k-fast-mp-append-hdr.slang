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
layout(set = 0, binding = 3) uniform sampler2D PfmPostColorFeedback;

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
    ),
    mat3(
        0.64, 0.33, 1-0.64-0.33,
        0.30, 0.60, 1-0.30-0.60,
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
    mat3( // sRGB
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

const float crtDemodulators[][2][3] = {
    // Index 8
    // CXA2025AS (JP mode)
    // Used in Sony Trinitron ~1997
    {
        {95, 240, 0}, // angles (degrees)
        {0.78, 0.3, 1.0} // gains
    },
    
    // Index 9
    // CXA2025AS (US mode)
    // Used in Sony Trinitron ~1997
    {
        {112, 252, 0}, // angles (degrees)
        {0.83, 0.3, 1.0} // gains
    },

    // Index 13
    // TA7644BP
    // Used in 1985 Toshiba Blackstripe CF2005
    // https://github.com/ChthonVII/gamutthingy/issues/1#issuecomment-2679838025
    {
        {107, 240, 0}, // angles (degrees)
        {0.95, 0.31, 1.0} // gains
    },

    // Index 12
    // Unknown chip used in 1989 RCA ColorTrak Remote E13169GM
    // US model
    // calculated from measurements by Patchy68k
    // https://github.com/ChthonVII/gamutthingy/issues/1#issuecomment-2672961597
    {
        {94.5488524399, 255.376054365, 0}, // angles (degrees)
        {0.806809988011, 0.295471057738, 1.0} // gains
    },

    // Index 15
    // Panasonic CT-36D30B measured by Patchy68k
    {
      {101.580982936, 232.937328893, 0},
      {0.91062624791989, 0.388131199173125, 1.0}
    }
};

float crtTintColor[][2] = {
    {3.25, 1.19},
    {-1.0, 1.19},
    {0.0, 1.13},
    {0.25, 1.20},
    {0.0, 0.95}
};

const vec3 crtWhites[] = {
    whiteLookup[3], // 9300K+27MPCD
    whiteLookup[3], // 9300K+27MPCD
    whiteLookup[3], // 9300K+27MPCD
    vec3(0.29519, 0.31065, 1 - 0.29519 - 0.31065) / 0.31065, // 8000K (daylight)
    whiteLookup[1] // D65
};

int decoderMethod[] = {
    1, // US SMPTE-C
    1, // US Standard
    1, // US Consumer 9300K (Toshiba 1985)
    1, // US Consumer 8000K (RCA 1989)
    1, // US Consumer 8700K (Average)
    1, // JP Standard
    1, // JP Consumer 9300K
    0, // JP Consumer 12500k
    0, // JP Guessed 8500K
    0, // jp guessed 14000k
    0, // US adapted 9300K 
    0, // US undapted 9300K 
    0, // US undapted 9300K alt
    1, // US Standard d65
    0, // dummy D93
    0, // dummy 9300k27mpcd
    0, // dummy d65
    0, // dummy c
    1, // US Consumer d65
    0, // US Alternate Standard C
};

float nealRateLookup[] = {
    1.0, // US SMPTE-C
    0.8, // US Standard
    0.75, // US Consumer 9300K (Toshiba 1985)
    0.70, // US Consumer 8000K (RCA 1989)
    0.75, // US Consumer 8700K (Average)
    0.75, // JP Standard
    0.70, // JP Consumer 9300K
    0.8, // JP Consumer 12500k
    0.8, // JP Guessed 8500K
    0.8, // jp guessed 14000k
    0.8, // US adapted 9300K 
    0.8, // US undapted 9300K 
    0.8, // US undapted 9300K alt
    0.8, // US Standard d65
    0.8, // dummy D93
    0.8, // dummy 9300k27mpcd
    0.8, // dummy d65
    0.8, // dummy c
    0.8, // US Consumer d65
    0.8, // US Alternate Standard C
};

float nealWhiteAdjLookup[] = {
    1, // US SMPTE-C
    1, // US Standard
    1.07, // US Consumer 9300K (Toshiba 1985)
    0.95, // US Consumer 8000K (RCA 1989)
    1, // US Consumer 8700K (Average)
    1, // JP Standard
    1, // JP Consumer 9300K
    1, // JP Consumer 12500k
    1, // JP Guessed 8500K
    1, // jp guessed 14000k
    1, // US adapted 9300K 
    1, // US undapted 9300K 
    1, // US undapted 9300K alt
    1, // US Standard d65
    1, // dummy D93
    1, // dummy 9300k27mpcd
    1, // dummy d65
    1, // dummy c
    1, // US Consumer d65
    1, // US Alternate Standard C
};

float nealSatFactorLookup[] = {
    1, // US SMPTE-C
    1, // US Standard
    1.08, // US Consumer 9300K (Toshiba 1985)
    1.14, // US Consumer 8000K (RCA 1989)
    1.05, // US Consumer 8700K (Average)
    1, // JP Standard
    1.06, // JP Consumer 9300K
    1, // JP Consumer 12500k
    1, // JP Guessed 8500K
    1, // jp guessed 14000k
    1, // US adapted 9300K 
    1, // US undapted 9300K 
    1, // US undapted 9300K alt
    1, // US Standard d65
    1, // dummy D93
    1, // dummy 9300k27mpcd
    1, // dummy d65
    1, // dummy c
    1, // US Consumer d65
    1, // US Alternate Standard C
};

int decoderStdPrims[] = {
    1, // US SMPTE-C
    0, // US Standard
    0, // US Consumer 9300K (Toshiba 1985)
    0, // US Consumer 8000K (RCA 1989)
    0, // US Consumer 8700K (Average)
    0, // JP Standard
    0, // JP Consumer 9300K
    0, // JP Consumer 12500k
    0, // JP Guessed 8500K
    0, // jp guessed 14000k
    0, // US adapted 9300K 
    0, // US undapted 9300K 
    0, // US undapted 9300K alt
    0, // US Standard d65
    3, // dummy D93
    3, // dummy 9300k27mpcd
    3, // dummy d65
    3, // dummy c
    0, // US Consumer d65
    0, // US Alternate Standard C
};

vec3 decoderStdWhite[] = {
    whiteLookup[1], // US SMPTE-C
    whiteLookup[0], // US Standard
    whiteLookup[0], // US Consumer 9300K
    whiteLookup[0], // US Consumer 8000K
    whiteLookup[0], // US Consumer 8700K
    whiteLookup[2], // JP Standard
    whiteLookup[2], // JP consumer 9300k
    whiteLookup[2], // JP consumer 12500k
    whiteLookup[2], // jp guessed 8500k
    whiteLookup[2], // jp guessed 14000k
    whiteLookup[1], // US Adapted 9300K
    whiteLookup[1], // US undapted 9300K for d65
    whiteLookup[0], // US undapted 9300K
    whiteLookup[1], // US Standard d65
    whiteLookup[2], //  dummy d93
    whiteLookup[3], //  dummy 9300k+27mpcd
    whiteLookup[1], // dummy d65
    whiteLookup[0], // dummy c
    whiteLookup[0], // US Consumer d65
    whiteLookup[0], // US Alternate Standard C
};

vec3 decoderDstWhite[] = {
    whiteLookup[1], // US SMPTE-C
    whiteLookup[0], // US Standard
    whiteLookup[3] * 0.945, // us consumer 9300k
    vec3(0.29519, 0.31065, 1 - 0.29519 - 0.31065) / 0.31065 * 1.017, // us consumer 8000K
    vec3(0.28916, 0.30393, 1 - 0.28916 - 0.30393) / 0.30393, // US Consumer 8700K (From Donfrio's paper on CRT white balances. A few sampled CRTs were clustered around this point.)
    whiteLookup[2], // JP Standard
    whiteLookup[3], // JP consumer 9300k
    vec3(0.265, 0.279,1-.265-.279)/.279 * 0.993, // JP consumer 12500k. Note that 12500k is only a CCT, whereas this point is the reverse-engineered xy coordinate from the Sony CXA1464AS with 2.2 gamma and Sony Trinitron phosphors.
    vec3(0.29076,0.30573,1-0.29076-0.30573)/0.30573, // JP guessed 8500k (Daylight CCT. According to the Dogway's Grading Shader (slang) thread on RetroArch, there are reports of Japan CRTs from 8200K to 8800K.)
    vec3(0.26066, 0.27436, 1-0.26066-0.27436)/0.27436, // JP guessed 14000k (Sampled from AMERICAN Panasonic CT-36D30B from 2000, with white balance set to "Cool")
    whiteLookup[3], // us adapted 9300k for d65
    whiteLookup[3], // us unadapted 9300k for d65
    whiteLookup[3], // us unadapted 9300k
    whiteLookup[1], // US Standard d65
    whiteLookup[2], //  dummy d93
    whiteLookup[3], //  dummy 9300k+27mpcd
    whiteLookup[1], // dummy d65
    whiteLookup[0], // dummy c
    whiteLookup[1], // US Consumer D65
    whiteLookup[0], // US Alternate Standard C
};

vec3 decoderInputs[][3] = {
    {vec3(0.5, 0.35, 1-0.5-0.35)/0.35, vec3(0.4, 0.45, 1-0.4-0.45)/0.45, vec3(0)}, // US SMPTE-C
    {vec3(0.5, 0.35, 1-0.5-0.35)/0.35, vec3(0.4, 0.45, 1-0.4-0.45)/0.45, vec3(0.37, 0.22,1-0.37-0.22)/0.22}, // US Standard
    {vec3(0.4008,0.46,1-0.4008-0.46)/0.46, vec3(0.48,0.34,1-0.48-0.34)/0.34, vec3(0)}, // US Consumer 9300K
    {vec3(0.472,0.364,1-.472-.364)/.364,vec3(.3508,.414,1-.3508-.414)/.414,vec3(0)}, // US Consumer 8000K
    {vec3(0.476,0.352,1-.476-.352)/.352,vec3(.3758,.437,1-.3758-.437)/.437,vec3(0)}, // US Consumer 8700K
    {vec3(0.5, 0.35, 1-0.5-0.35)/0.35, vec3(0.4, 0.45, 1-0.4-0.45)/0.45, vec3(0.37, 0.22,1-0.37-0.22)/0.22}, // JP Standard
    {vec3(0.476,0.352,1-.476-.352)/.352,vec3(.3758,.437,1-.3758-.437)/.437,vec3(0)}, // JP consumer 9300k
    {vec3(.464,.372,1-.464-.372)/.372,vec3(.416,.453,1-.416-.453)/.453,vec3(0)}, // JP consumer 12500k (cxa1464as)
    {vec3(0.476,0.352,1-.476-.352)/.352,vec3(.3758,.437,1-.3758-.437)/.437,vec3(0)}, // JP guessed 8500k
    {vec3(0.476,0.352,1-.476-.352)/.352,vec3(.3758,.437,1-.3758-.437)/.437,vec3(0)}, // JP guessed 14000k
    {vec3(0.5, 0.35, 1-0.5-0.35)/0.35, vec3(0.4, 0.45, 1-0.4-0.45)/0.45, vec3(0.37, 0.22,1-0.37-0.22)/0.22}, // US adapted 9300K for d65
    {vec3(0.476,0.352,1-.476-.352)/.352,vec3(.3758,.437,1-.3758-.437)/.437,vec3(0)}, // US unadapted 9300k for d65
    {vec3(0.476,0.352,1-.476-.352)/.352,vec3(.3758,.437,1-.3758-.437)/.437,vec3(0)}, // US better unadapted 9300k 
    {vec3(0.5, 0.35, 1-0.5-0.35)/0.35, vec3(0.4, 0.45, 1-0.4-0.45)/0.45, vec3(0.37, 0.22,1-0.37-0.22)/0.22}, // US Standard d65
    {vec3(0.476,0.352,1-.476-.352)/.352,vec3(.3758,.437,1-.3758-.437)/.437,vec3(0)}, // dummy d93
    {vec3(0.476,0.352,1-.476-.352)/.352,vec3(.3758,.437,1-.3758-.437)/.437,vec3(0)}, // dummy 9300k27mpcd 
    {vec3(0.476,0.352,1-.476-.352)/.352,vec3(.3758,.437,1-.3758-.437)/.437,vec3(0)}, // dummy d65
    {vec3(0.476,0.352,1-.476-.352)/.352,vec3(.3758,.437,1-.3758-.437)/.437,vec3(0)}, // dummy c 
    {vec3(0.476,0.352,1-.476-.352)/.352,vec3(.3758,.437,1-.3758-.437)/.437,vec3(0)}, // US Consumer D65
    {vec3(0.476,0.352,1-.476-.352)/.352,vec3(.3758,.437,1-.3758-.437)/.437,vec3(0)}, // US Alternate Standard C
};

vec3 decoderOutputs[][3] = {
    {decoderInputs[0][0], decoderInputs[0][1], decoderInputs[0][2]}, // US SMPTE C
    {decoderInputs[1][0], decoderInputs[1][1], decoderInputs[1][2]}, // US Standard
    {decoderInputs[2][0]*1.021, decoderInputs[2][1], decoderInputs[2][2]}, // US Consumer 9300K
    {decoderInputs[3][0]*1.021, decoderInputs[3][1], decoderInputs[3][2]}, // US Consumer 8000K
    {decoderInputs[4][0], decoderInputs[4][1], decoderInputs[4][2]}, // US Consumer 8700K
    {decoderInputs[5][0], decoderInputs[5][1], decoderInputs[5][2]}, // JP Standard
    {decoderInputs[9][0], decoderInputs[9][1], decoderInputs[9][2]}, // JP guessed 9300k
    {vec3(.464,.372,1-.464-.372)/.372*1.044,vec3(.416,.453,1-.416-.453)/.453*1.018,vec3(0)}, // JP consumer 12500k (cxa1464as)
    {decoderInputs[9][0], decoderInputs[9][1], decoderInputs[9][2]}, // JP guessed 8500k
    {decoderInputs[9][0], decoderInputs[9][1], decoderInputs[9][2]}, // JP guessed 14000k
    {decoderInputs[1][0], decoderInputs[1][1], decoderInputs[1][2]}, // US adapted 9300K
    {decoderInputs[4][0], decoderInputs[4][1], decoderInputs[4][2]}, // US unadapted 9300k
    {decoderInputs[4][0], decoderInputs[4][1], decoderInputs[4][2]}, // US unadapted 9300k alt
    {decoderInputs[1][0], decoderInputs[1][1], decoderInputs[1][2]}, // US Standard alt
    {decoderInputs[4][0], decoderInputs[4][1], decoderInputs[4][2]}, // dummy d93
    {decoderInputs[4][0], decoderInputs[4][1], decoderInputs[4][2]}, // dummy 9300k27
    {decoderInputs[4][0], decoderInputs[4][1], decoderInputs[4][2]}, // dummy d65
    {decoderInputs[4][0], decoderInputs[4][1], decoderInputs[4][2]}, // dummy c
    {decoderInputs[4][0], decoderInputs[4][1], decoderInputs[4][2]}, // US Consumer D65
    {decoderInputs[4][0], decoderInputs[4][1], decoderInputs[4][2]}, // US Alternate Standard C
};

// Type 0: Change white point, don't adapt other points.
// Type 1: Change white point, adapt via CAT16 matrix

int adaptType[] = {
    0, // US SMPTE C
    0, // US Standard
    0, // US 9300k
    0, // US 8000K
    0, // US 8700k
    0, // jp standard
    0, // jp 9300k+27mpcd
    0, // jp 12500k
    0, // jp unadapted 8500k
    0, // jp unadapted 14000k
    1, // US Adapted 9300K+27MPCD
    0, // US Undapted 9300K+27MPCD
    0, // US Undapted 9300K+27MPCD alt
    0, // US Standard alt
    0, // dummy d93
    0, // dummy 9300k27mpcd
    0, // dummy d65
    0, // dummy c
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

// Based on BT.1886.
// Both the Annex 1 equation and the Appendix 1 equation are supported.
// Annex 1 is a simple 2.4 power law equation with adjustable brightness. This is established as the standard.
// Appendix 1 is meant to more precisely match a CRT's response. It is not the standard, but it's provided for cases where a more precise match is needed.
// approxGamma must be from 1.1 to 3.0. If it is not, it will be clamped.
// This is meant to represent the CRT's real output. Changing luminance directly will cause a change in chromaticity.
// This should not be used in cases where we isolate average chromaticity from luminance. Just use approxGamma straight-up instead.
float bt1886(float prime, float approxGamma, bool use24) {

    // It's a bit spaghetti to have this use24 parameter and pf_gammatype thrown around this badly
    if(global.pf_gammatype < 0.5) {
        return pow(max(prime, 0), approxGamma);
    }

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

// If an RGB channel is over 1.0, figure out some way to display this color.
vec3 compress(vec3 uncompressed) {

    mat3 srgbXyzToRgbD65 = xyzToRgbMatrix(getCRTPrimaries(), srgbWhite);
    vec3 uncompressedRgb = srgbXyzToRgbD65 * uncompressed;

    if(params.pf_clipping > 2.5) {
        // Expose
        if(max(uncompressedRgb.r, max(uncompressedRgb.g, uncompressedRgb.b)) > 1.01) // Tolerate small amounts of clipping
            return 1 - uncompressed;
        else
            return uncompressed;
    } else if(params.pf_clipping > 1.5) {
        // Clamp
        return uncompressed;
    } else if(params.pf_clipping > 0.5) {
        // Darken
        return uncompressed / max(1.0, max(uncompressedRgb.r, max(uncompressedRgb.g, uncompressedRgb.b)));
    }
    // The rest of this desaturates the color back in bounds using a binary search with CIELAB.
    
    // If brighter than white, then white is the best we can do
    if(uncompressed.y >= 1.0) {
        return srgbWhite;
    }

    // If already in bounds, there's no need to desaturate
    if(max(uncompressedRgb.r, max(uncompressedRgb.g, uncompressedRgb.b)) <= 1.0) {
        return uncompressed;
    }

    vec3 whiteRefLab = srgbWhite; // Desaturate towards D65, not towards the CRT's nominal white.
    vec3 tmpLab;
#define pow13(val) pow(val, 1.0 / 3.0)
#define xyzToAb(xyzTest) (tmpLab = ((xyzTest) / (xyzTest).y) / ((whiteRefLab) / (whiteRefLab).y), vec2(500 * (pow13(tmpLab.x) - pow13(tmpLab.y)), 200 * (pow13(tmpLab.y) - pow13(tmpLab.z))))
#define abToXyz(ab) ((whiteRefLab) / (whiteRefLab).y * pow(vec3(1.0 + (ab).x / 500, 1.0, 1.0 - (ab).y / 200), vec3(3.0)))

    vec2 innerAb = vec2(0);
    vec2 outerAb = xyzToAb(uncompressed);
    // Binary search to find best solution.
    // More iterations gives more precise results.
    for(int i = 0; i < 10; i++) {
        vec2 midAb = (innerAb + outerAb) / 2;
        vec3 midRgb = srgbXyzToRgbD65 * uncompressed.y * abToXyz(midAb);
        if(max(midRgb.r, max(midRgb.g, midRgb.b)) >= 1.0) {
            outerAb = midAb;
        } else {
            innerAb = midAb;
        }
    }

    // innerAb is the best result.
    return abToXyz(innerAb) * uncompressed.y;

#undef pow13
#undef xyzToAb
#undef abToXyz
}

void main() {
    vec3 crtColor = texture(Source, vTexCoord).rgb;
    mat3 finalHdrMat = xyzToRgbMatrix(hdrPrimaries[int(global.pf_hdr_gamut + 0.5)], srgbWhite) * rgbToXyzMatrix(getCRTPrimaries(), srgbWhite);
    vec3 finalColor = linearToSrgb(finalHdrMat * srgbToLinear(crtColor));
    FragColor = vec4(finalColor, 1.0);
}
