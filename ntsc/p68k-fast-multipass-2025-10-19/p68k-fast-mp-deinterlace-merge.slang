#version 450

/*

Patchy68k Fast Multipass - Simulation of analog video signal artifacts and color correction
Copyright (C) 2025 Patchy68k/PlainOldPants

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>. 

*/

/*

This pass performs more deinterlacing options on a weave-deinterlaced image.

*/

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;

    float pfm_forceInterlace,
          pfm_deinterlaceMethod;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;

} global;

#pragma parameter pfm_forceInterlace "Force enable interlace: 0:Off 1:On" 0 0 1 1
#pragma parameter pfm_deinterlaceMethod "Deinterlace method: 0:Weave 1:Average 2:Bob" 0 0 2 1

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

    vec3 stdRGB;
    if((params.OutputSize.y > 300 || params.pfm_forceInterlace > 0.5)) {
        if(params.pfm_deinterlaceMethod < 0.5) {
            // Weave
            stdRGB = texture(Source, vTexCoord).rgb;
        } else if(params.pfm_deinterlaceMethod < 1.5) {
            // Average 2 frames
            vec3 above = pow(clamp(texture(Source, vTexCoord + vec2(0, -params.SourceSize.w)).rgb, 0, 1), vec3(2.2));
            vec3 here = pow(clamp(texture(Source, vTexCoord).rgb, 0, 1), vec3(2.2));
            stdRGB = pow((above + here) / 2.0, vec3(1.0 / 2.2));
        } else {
            // Bob
            if(int(mod(vTexCoord.y * params.OutputSize.y, 2)) != params.FrameCount % 2) {
                stdRGB = texture(Source, vTexCoord + vec2(0, -params.SourceSize.w)).rgb;
            } else {
                stdRGB = texture(Source, vTexCoord).rgb;
            }
        }
    } else {
        stdRGB = texture(Source, vTexCoord).rgb;
    }

    FragColor = vec4(stdRGB, 1.0);
}
