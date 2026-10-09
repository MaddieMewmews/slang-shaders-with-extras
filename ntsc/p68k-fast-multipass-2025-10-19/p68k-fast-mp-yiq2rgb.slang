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

This pass performs the following operations (not in order):

* Convert RGB into YIQ (default) or Y B-Y R-Y
* Correct the transfer characteristic (gamma):
    * Electro-optical transfer: power law, sRGB piecewise, 170M/240M/BT.709 (default), BT.1886 Annex 1, or BT.1886 Appendix 1
    * Opto-electronic transfer: power law, sRGB piecewise, 170M/240M/BT.709 (default), BT.1886 Annex 1, or BT.1886 Appendix 1
* Correct RGB primaries and reference white:
    * Input primaries: sRGB, SMPTE C (default), NTSC 1953, EBU, Japan
    * Input white: D65 (default), C, 9300K+8MPCD
    * Output primaries: sRGB, SMPTE C (default), NTSC 1953
    * Output white: D65 (default), C, 9300K+8MPCD

Note that many of the above options are not allowed by the video standard.
No effort is made to prevent clipping when converting between different primaries. Please be careful.

When putting this in a shader preset, use the following settings:

Input must use nearest-neighbor interpolation.
Input sizes should be the same as the output sizes.
Ideally, input horizontal resolution must be able to divide 2560 as an integer. For instance, 256, 320, 512, or 640.
Framebuffer should use floating point, not integers.
Frame count modulus should be 4 if interlacing is enabled, or 2 if interlacing is disabled.

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
          pfm_srgbEotf;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

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

void main() {

    // SMPTE 170M standard conversions from RGB to YIQ
    mat3 rgbToYiq = mat3(
        0.299, 0.5959, 0.2115,
        0.587, -0.2746, -0.5227,
        0.114, -0.3213, 0.3112
    );

    vec3 inputRgb = texture(Source, vTexCoord).rgb;
    FragColor = vec4(inverse(rgbToYiq) * inputRgb, 1.0);
}
