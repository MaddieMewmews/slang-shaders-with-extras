#version 450

/*

Patchy68k Fast Multipass - Simulation of analog video signal artifacts and color correction
Copyright (C) 2025 Patchy68k/PlainOldPants

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>. 

*/

#pragma name PfmEncodePass


layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
    float pfm_offsetFrameMod,
          pfm_pedestal;
} params;

#pragma parameter pfm_ccWantRes "Console default resolution in pixels (0=Don't care)" 0 0 10000 1
#pragma parameter pfm_ccNum "Color carrier wavelength numerator" 1 1 10000 1
#pragma parameter pfm_ccDenom "Color carrier wavelength denominator" 1 1 10000 1
#pragma parameter pfm_offsetInit "Color initial offset" 0 0 1 0.01
#pragma parameter pfm_offsetLine "Color per-line offset" 2 -10 10 1
#pragma parameter pfm_offsetFrame "Color per-frame offset" 2 -10 10 1
#pragma parameter pfm_offsetFrameMod "Color per-frame modulus" 2 1 10 1
#pragma parameter pfm_pedestal "Pedestal error: 0:Off 1:Raise 2:Lower" 0 0 2 1

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

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


bool InColorp (int p, int color)
{
    return ((color + p) % (12) < (6));
}

#define TO_INT2(X) int(floor(((X) * 3.0) + 0.5))
#define TO_INT3(X) int(floor(((X) * 7.0) + 0.5))
#define TO_INT4(X) int(floor(((X) * 15.0) + 0.5))

// Basic square wave simulation of NES composite video.
// This is only a basic simulation. Real hardware has more going on.
// * This doesn't simulate the varying impedance levels that cause hue rotation and other substantial distortions.
// * The NES has a much blurrier RF lowpass than other consoles, leading to more issues. That's not simulated either.
// * When decoding, the square shape and weird de-emphasis probably cause other issues too, which aren't simulated.
float nesSignal(int color, int level, int emphasis, int p) {
    // This code is taken from both the nesdev wiki and from GTU-famicom, the latter created by aliaspider.

    if(color > 13)  
        level = 1;

    float black = 0.312;
    float white = 1.100;
    
    // These new levels originate from lidnariq's post on nesdev in 2015.
    // https://forums.nesdev.org/viewtopic.php?p=159266#p159266
    float levels[16] = float[] (
        0.228f, 0.312f, 0.552f, 0.880f, // Signal low
        0.616f, 0.840f, 1.100f, 1.100f, // Signal high
        0.192f, 0.256f, 0.448f, 0.712f, // Signal low, attenuated
        0.500f, 0.676f, 0.896f, 0.896f  // Signal high, attenuated
    );
    
    int amtAtten = 0;

    if(((bool(emphasis & 1) && InColorp(p, 0)) ||
        (bool(emphasis & 2) && InColorp(p, 4)) ||
        (bool(emphasis & 4) && InColorp(p, 8))) && color < 14) 
    {
        amtAtten = 8;
    }

    float low  = levels[0 + level + amtAtten];
    float high = levels[4 + level + amtAtten];

    if(color == 0)
        low = high;
    else if(color > 12)
        high = low;

    float sig = InColorp(p, color) ? high : low;

    sig = (sig - black) / (white - black);

    return sig;
}

void main() {
    vec3 sampRaw = texture(Source, vTexCoord * vec2(0.5 * params.SourceSize.z * params.OutputSize.x, 1)).rgb;
    int color    = TO_INT4(sampRaw.x);
    int level    = TO_INT2(sampRaw.y);
    int emphasis = TO_INT3(sampRaw.z);
    int p = int(mod(vTexCoord.x * params.OutputSize.x * 4, 12) + mod(vTexCoord.y * params.OutputSize.y * 4, 12) + int(params.FrameCount % int(params.pfm_offsetFrameMod + 0.5)) * 4 % 12 + 0.5);
    vec4 samps;
    for(int i = 0; i < 4; i++) {
        samps[i] = nesSignal(color, level, emphasis, (p + i + 8) % 12);
    }
    if(params.pfm_pedestal > 1.5) {
        samps = (samps - 0.075) / (1.0 - 0.075);
    } else if(params.pfm_pedestal > 0.5) {
        samps = (samps + 0.075) / (1.0 + 0.075);
    }
    FragColor = samps;
}