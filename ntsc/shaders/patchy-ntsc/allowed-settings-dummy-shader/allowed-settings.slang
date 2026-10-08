#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma parameter allowed_settings_header "===== Basic settings that most people want =====" 0.0 0.0 0 1

#pragma parameter pn_connection_type "Cable: RF | Composite | S-Video | Component" 0 -1 2 1

#pragma parameter pn_test_pattern "Test Pattern: Color Bars, Ramps, HSV, Focused HSV, NES Full" 0 0 5 1
#pragma parameter pn_test_pattern_split "Test pattern split mode (if available)" 0 0 1 1
#pragma parameter pn_demodulator_std "R-Y/G-Y/B-Y preset: Rec. 601, Rec. 709, 2*JP, 5*US, Custom" 8 0 9 1
#pragma parameter pn_knob_brightness "Brightness (Black Level) (default 0.1 for BT.1886 except Grade)" 0.15 -0.5 0.5 0.01
#pragma parameter pn_knob_tint "Tint (Hue Rotation)" 0 -45 45 0.5
#pragma parameter pn_knob_saturation "Color (Saturation)" 1.0 0 5 0.025
#pragma parameter lut_toggle "Gamut: sRGB, P22-80s, P22-90s, P22-J, Trinitron P22" 4 0 4 1
#pragma parameter lut_index "Ref. White: D65, C, 9300K+27MPCD, 8500K, CCT, (x,y), Measured" 1 0 6 1
#pragma parameter lut_chroma_adapt "(For P22-J and Trinitron w/ NTSC-J) Chromatic Adaptation to D65" 0 0 1 1

#pragma parameter pn_demodulator_luma_sinc_preset "(7) Easy Sharpness (Lowpass Cutoff Rate)" 2.6 2.15 2.90 0.15
#pragma parameter pn_demodulator_uv_filter_type "B-Y R-Y Filter Type" 1 1 2 1

#pragma parameter pn_nes_phase_mod "NES Battletoads / Battletoads Double Dragon Phase Cycle" 0 0 1 1
#pragma parameter pn_genesis_jailbar_enable "Enable Genesis jailbars on solid backgrounds (Composite/RF)" 0 0 1 1

#pragma parameter pn_noise_severity "Noise overall severity factor" 0.9 0.0 20.0 0.025
#pragma parameter pn_noise_rand_offset "Noise random seed" 448 0 999 1


#pragma parameter allowed_settings_footer "===== NOTICE: Please do not edit anything under this line =====" 0.0 0.0 0 1

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

void main()
{
   FragColor = vec4(texture(Source, vTexCoord).rgb, 1.0);
}

