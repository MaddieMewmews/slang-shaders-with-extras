#version 450

/*
Patchy NTSC
Copyright (C) 2024 Patchy68k/PlainOldPants

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>. 

*/

// This pass adds in the noise that was already computed in an earlier pass.

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    vec4 FinalViewportSize;
} params;

// Includes constants, global, and all parameters
#include "patchy-ntsc-inc-params.inc"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D GenerateNoiseFeedback;

// Includes lowpass and bandpass functions
#include "patchy-ntsc-inc-filters.inc"

#define euler 2.7182818284

float getNoise() {
    int internalX = int(mod(vTexCoord.x * params.OriginalSize.x, 1.0) * 4 + 0.5);
    
    return texture(GenerateNoiseFeedback, vTexCoord)[internalX];
}

void main()
{
    vec4 orig = texture(Source, vTexCoord);
    if(global.pn_connection_type < -0.5)
        orig.r += getNoise();
    
    FragColor = orig;
}

