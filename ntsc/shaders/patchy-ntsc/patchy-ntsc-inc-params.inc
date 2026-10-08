
/*
Patchy NTSC
Copyright (C) 2024 Patchy68k/PlainOldPants

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>. 

*/

#ifndef __patchy_ntsc_inc_params_inc__
#define __patchy_ntsc_inc_params_inc__

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    
    float pn_test_pattern,
          pn_test_pattern_split,
          pn_signal_res,
          pn_width_uncropped,
          pn_height_uncropped,
          pn_width_integer_mul,
          pn_height_integer_mul,
          pn_dual_width_mode,
          pn_width_secondary_uncropped,
          pn_color_carrier_preset,
          pn_scanline_dur,
          pn_total_scanline_dur,
          pn_num_lines,
          pn_color_amplitude,
          pn_color_freq,
          pn_color_init_offset,
          pn_color_line_offset,
          pn_color_screen_offset,
          pn_color_screen_offset_modulo,
          pn_nes_enable,
          pn_nes_rgb_enable,
          pn_nes_phase_mod,
          pn_nes_real_capture,
          pn_nes_hue_skew,
          pn_genesis_palette,
          pn_genesis_jailbar_enable,
          pn_genesis_jailbar_offset,
          pn_genesis_jailbar_amplitude,
          pn_rgb_blur_enable,
          pn_rgb_blur_amount,
//          pn_modulator_std,
          pn_modulator_luma_filter_type,
          pn_modulator_luma_filter_preset,
          pn_modulator_luma_filter_width,
          pn_modulator_luma_filter_level,
          pn_modulator_luma_notch_width,
          pn_modulator_luma_notch_lo,
          pn_modulator_luma_notch_hi,
          pn_modulator_luma_notch_intensity,
          pn_modulator_luma_antihigh_width,
          pn_modulator_luma_antihigh_cancelfreq,
          pn_modulator_luma_antihigh_cutofffreq,
          pn_modulator_luma_antihigh_intensity,
          pn_modulator_luma_radius,
          pn_modulator_luma_sigma,
          pn_modulator_luma_res,
          pn_modulator_luma_int_dist,
          pn_modulator_luma_int_off,
          pn_modulator_luma_int_rate,
          pn_modulator_luma_eq_f_lo,
          pn_modulator_luma_eq_f_hi,
          pn_modulator_luma_eq_g_lo,
          pn_modulator_luma_eq_g_mid,
          pn_modulator_luma_eq_g_hi,
          pn_modulator_luma_eq_off,
          pn_modulator_luma_eq_dist,
          pn_modulator_chroma_filter_type,
          pn_modulator_chroma_filter_width,
          pn_modulator_chroma_filter_level,
          pn_modulator_chroma_filter_level_diff,
          pn_modulator_chroma_eq_f_lo,
          pn_modulator_chroma_eq_f_hi,
          pn_modulator_chroma_eq_g_lo,
          pn_modulator_chroma_eq_g_mid,
          pn_modulator_chroma_eq_g_hi,
          pn_modulator_chroma_eq_off,
          pn_modulator_chroma_eq_dist,
          pn_demodulator_std,
          pn_demodulator_std_defaults,
          pn_demodulator_r_off,
          pn_demodulator_r_amp,
          pn_demodulator_g_off,
          pn_demodulator_g_amp,
          pn_demodulator_luma_filter_type,
          pn_demodulator_luma_test,
          pn_demodulator_luma_test_threshold,
          pn_demodulator_luma_filter_width,
          pn_demodulator_luma_filter_level,
          pn_demodulator_luma_notch_width,
          pn_demodulator_luma_notch_lo,
          pn_demodulator_luma_notch_hi,
          pn_demodulator_luma_notch_intensity,
          pn_demodulator_luma_antihigh_width,
          pn_demodulator_luma_antihigh_cancelfreq,
          pn_demodulator_luma_antihigh_cutofffreq,
          pn_demodulator_luma_radius,
          pn_demodulator_luma_sigma,
          pn_demodulator_luma_int_dist,
          pn_demodulator_luma_int_off,
          pn_demodulator_luma_int_rate,
          pn_demodulator_luma_res,
          pn_demodulator_luma_sinc_preset,
          pn_demodulator_luma_eq_f_lo,
          pn_demodulator_luma_eq_f_hi,
          pn_demodulator_luma_eq_g_lo,
          pn_demodulator_luma_eq_g_mid,
          pn_demodulator_luma_eq_g_hi,
          pn_demodulator_luma_eq_off,
          pn_demodulator_luma_eq_dist,
          pn_demodulator_chroma_filter_type,
          pn_demodulator_chroma_filter_width,
          pn_demodulator_chroma_filter_level,
          pn_demodulator_chroma_filter_level_diff,
          pn_demodulator_chroma_eq_f_lo,
          pn_demodulator_chroma_eq_f_hi,
          pn_demodulator_chroma_eq_g_lo,
          pn_demodulator_chroma_eq_g_mid,
          pn_demodulator_chroma_eq_g_hi,
          pn_demodulator_chroma_eq_off,
          pn_demodulator_chroma_eq_dist,
          pn_demodulator_uv_filter_type,
          pn_demodulator_uv_filter_width,
          pn_demodulator_uv_sinc_width,
          pn_demodulator_uv_sinc_level,
          pn_demodulator_uv_int_off,
          pn_demodulator_uv_int_dist,
          pn_demodulator_uv_int_rate,
          pn_connection_type,
          pn_noise_rand_offset,
//          pn_noise_min_rate,
//          pn_noise_max_rate,
          pn_noise_base_rate,
          pn_noise_lower_rate,
          pn_noise_mode,
          pn_noise_counter,
          pn_noise_severity,
          pn_bad_rgb_gamma,
          pn_auto_contrast,
          pn_knob_contrast,
          pn_knob_brightness,
          pn_knob_saturation,
          pn_knob_tint,
          pn_rgb_smear_enable,
          pn_rgb_smear_clamp,
          pn_rgb_smear_rate,
          pn_rgb_smear_limit,
          pn_rgb_smear_res,
          pn_gamma_type,
          pn_g_CRT_l,
          pn_blackfix_patchy,
          pn_power_gamma;
} global;

#pragma parameter pn_comment_notice0 "===============================================================" 0 0 0 1
#pragma parameter pn_comment_notice1 "Patchy NTSC: Patchy68k/PlainOldPants's NTSC Signal/Color Shader" 0 0 0 1
#pragma parameter pn_comment_notice2 "To understand this stupidly long list of settings, please view" 0 0 0 1
#pragma parameter pn_comment_notice3 "the guide I posted on my thread on the Libretro Forums. If you" 0 0 0 1
#pragma parameter pn_comment_notice4 "aren't understanding something, don't be afraid to ask me on" 0 0 0 1
#pragma parameter pn_comment_notice5 "that thread. (Disclaimer: I'm not an expert on NTSC video, nor" 0 0 0 1
#pragma parameter pn_comment_notice6 "on CRT TVs. This shader is a work in progress, made from my" 0 0 0 1
#pragma parameter pn_comment_notice7 "limited knowledge from reading various sources on the web.)" 0 0 0 1
#pragma parameter pn_comment_notice8 "===============================================================" 0 0 0 1

#pragma parameter pn_comment_test_pattern "=== Test Patterns ===" 0 0 0 1
#pragma parameter pn_test_pattern "Test Pattern: Color Bars, Ramps, HSV, Focused HSV, NES Full" 0 0 5 1
#pragma parameter pn_test_pattern_split "Test pattern split mode (if available)" 0 0 1 1

#pragma parameter pn_comment_resolution "=== Auto detect cropped overscan and resolution changes ===" 0 0 0 1
#pragma parameter pn_signal_res "Signal samples per game pixel" 8 1 32 1
#pragma parameter pn_width_uncropped "Console Horizontal Resolution (pixels) (rec. even numbers only)" 320 128 720 1
#pragma parameter pn_height_uncropped "Console Vertical Resolution (pixels) (rec. 240 or 224 only)" 224 128 480 1
#pragma parameter pn_width_integer_mul "Detect integer-multiplied width (such as bsnes-mercury)" 1 0 1 1
#pragma parameter pn_height_integer_mul "Detect integer-multiplied height (such as interlaced video)" 1 0 1 1
#pragma parameter pn_dual_width_mode "Detect two horizontal resolutions (such as Genesis 320 vs 256)" 0 0 1 1
#pragma parameter pn_width_secondary_uncropped "Console Smaller Horizontal Resolution (pixels)" 256 128 720 1

#pragma parameter pn_comment_nes "=== NES Video Signal Settings ===" 0 0 0 1
#pragma parameter pn_comment_nes_palette "== Note: Use Mesen (not FCEUmm) and change palette to Raw ==" 0 0 0 1
#pragma parameter pn_nes_enable "Enable NES Video Signal Emulation" 0 0 1 1
//#pragma parameter pn_nes_rgb_enable "Enable NES RGB mod (non-NES signal, with NES color)" 0 0 1 1
#pragma parameter pn_nes_phase_mod "NES Battletoads / Battletoads Double Dragon Phase Cycle" 0 0 1 1
#pragma parameter pn_nes_real_capture "NES color fix: Hue-skew | Real video capture LUT (unfinished)" 0 0 1 1
#pragma parameter pn_nes_hue_skew "NES hue-skew PPU version: 2C02G | 2C02E" 0 0 1 1

#pragma parameter pn_comment_genesis_jailbar "=== Genesis Settings ===" 0 0 0 1
#pragma parameter pn_genesis_palette "Genesis Plus GX color fix (0: Off (BlastEm), 1: Gen/MD, 2: SMS)" 0 0 2 1
#pragma parameter pn_genesis_jailbar_enable "Enable Genesis jailbars on solid backgrounds (Composite/RF)" 0 0 1 1
#pragma parameter pn_genesis_jailbar_offset "Genesis Jailbars Offset" 0 0 1 0.0625
#pragma parameter pn_genesis_jailbar_amplitude "Genesis Jailbars Severity" 1.0 0.1 30.0 0.1

#pragma parameter pn_comment_snes_settings "=== SNES Settings ===" 0 0 0 1
#pragma parameter pn_rgb_blur_enable "Enable RGB linear blur (such as 2-chip SNES)" 0 0 1 1
#pragma parameter pn_rgb_blur_amount "RGB linear blur distance" 1.0 0.25 2.0 0.125

#pragma parameter pn_comment_color_carrier "=== Color carrier settings (NES signal overrrides this) ===" 0 0 0 1
#pragma parameter pn_color_carrier_preset "Color carrier preset (0=Custom, 1-3=1phase/2phase/3phase)" 0 0 3 1
#pragma parameter pn_scanline_dur "Line Active Duration (uSec)" 47.7 1.0 300.0 0.01
#pragma parameter pn_total_scanline_dur "Signal Line Total Duration (uSec) (Affects noise)" 63.55 1 300 0.01
#pragma parameter pn_num_lines "Number of signal lines (Affects noise) (Editing is discouraged)" 262 250 275 1
#pragma parameter pn_color_amplitude "Color Carrier Amplitude" 1.0 0.025 10 0.025 
#pragma parameter pn_color_freq "Color Carrier Frequency (MHz) (Editing is not recommended)" 3.5795454 3.5795454 3.5795454 1
#pragma parameter pn_color_init_offset "Color Carrier Initial Offset (Cycles)" 0.1 0 1 0.02
#pragma parameter pn_color_line_offset "Color Carrier Per-Line Offset (Cycles)" 0 0 1 0.02
#pragma parameter pn_color_screen_offset "Color Carrier Per-Frame Offset (Cycles)" 0 0 1 0.02
#pragma parameter pn_color_screen_offset_modulo "Color Carrier Frame Count Modulo (1 = infinity)" 1 1 10 1

#pragma parameter pn_comment_connection "=== Video cable type (including console and CRT mods) ===" 0 0 0 1
#pragma parameter pn_connection_type "Cable: RF | Composite | S-Video | Component" 0 -1 2 1

#pragma parameter pn_comment_noise "=== RF noise settings (requires Cable=-1) ===" 0 0 0 1
#pragma parameter pn_noise_rand_offset "Noise random seed" 448 0 999 1
#pragma parameter pn_noise_base_rate "Noise base rate (increases exponentially)" 7.5 5.5 8.5 0.025
#pragma parameter pn_noise_lower_rate "Noise lower rate ratio (multiplies against base rate)" 2.5 0.0 9.975 0.025
#pragma parameter pn_noise_severity "Noise overall severity factor" 0.9 0.0 20.0 0.025
#pragma parameter pn_noise_counter "Amount of sine waves (higher is better but needs more power)" 300 5 2000 5
#pragma parameter pn_noise_mode "Noise adjustment mode" 2 0 3 1

//#pragma parameter pn_comment_modulator_std "=== Console video standard (Most are Rec. 601) ===" 0 0 0 1
//#pragma parameter pn_modulator_std "Modulator standard: Rec. 601 | Rec. 709" 0 0 1 1

#pragma parameter pn_comment_mod_luma_lowpass "=== (Not NES) Console's filtering luma/chroma before adding ===" 0 0 0 1
#pragma parameter pn_modulator_luma_filter_type "Mod. Luma Lowpass Type" 0 -2 3 1
#pragma parameter pn_modulator_luma_filter_preset "(Type -2) Genesis Specific Width+Cutoff Preset" 5 0 13 1
#pragma parameter pn_modulator_luma_nofilter "(Type -1) (No params) No luma filter" 0 0 0 1
#pragma parameter pn_modulator_luma_filter_width "Mod. Luma Lowpass (Type 0) Sinc Half-Width" 3 0 30 0.25
#pragma parameter pn_modulator_luma_filter_level "Mod. Luma Lowpass (Type 0) Sinc Cutoff Frequency (MHz)" 2.70 0.5 40.0 0.025
#pragma parameter pn_modulator_luma_notch_width "Mod. Luma Bandstop (Type 1) Sinc Half-Width" 2.5 0 30 0.125
#pragma parameter pn_modulator_luma_notch_lo "Mod. Luma Bandstop (Type 1) Sinc Low Frequency (MHz)" 3.4 0.5 40.0 0.025
#pragma parameter pn_modulator_luma_notch_hi "Mod. Luma Bandstop (Type 1) Sinc High Frequency (MHz)" 3.2 0.025 40.0 0.025
#pragma parameter pn_modulator_luma_notch_intensity "Mod. Luma Bandstop (Type 1) Filter Strength" 1.0 0.0 1.0 0.025
#pragma parameter pn_modulator_luma_antihigh_width "Mod. Luma Anti-Highpass (Type 2) Sinc Half-Width" 2.5 0 30 0.25
#pragma parameter pn_modulator_luma_antihigh_cancelfreq "Mod. Luma Anti-Highpass (Type 2) Cancel Freq (MHz)" 3.4 0.5 40.0 0.025
#pragma parameter pn_modulator_luma_antihigh_cutofffreq "Mod. Luma Anti-Highpass (Type 2) Cutoff Freq (MHz)" 3.2 0.025 40.0 0.025
#pragma parameter pn_modulator_luma_antihigh_intensity "Mod. Luma Anti-Highpass (Type 2) Filter Strength" 1.0 0.0 1.0 0.025
//#pragma parameter pn_modulator_luma_radius "Mod. Luma Lowpass (Type 1) Gaussian Blur Radius" 3.0 0.1 15.0 0.1
//#pragma parameter pn_modulator_luma_sigma "Mod. Luma Lowpass (Type 1) Gaussian Blur Sigma" 1.5 0.1 15.0 0.01
//#pragma parameter pn_modulator_luma_res "Mod. Luma Lowpass (Type 2) GTU Signal Res Y" 180 10 800 2
//#pragma parameter pn_modulator_luma_int_dist "Mod. Luma Lowpass (2) Leaky Integrator Distance" 5 0 30 0.25
//#pragma parameter pn_modulator_luma_int_off "Mod. Luma Lowpass (2) Leaky Integrator Offset (negative=Auto)" -1 -1 30 0.25
//#pragma parameter pn_modulator_luma_int_rate "Mod. Luma Lowpass (2) Leaky Integrator Rate" 5.0 0.0 100.0 0.025
//#pragma parameter pn_modulator_luma_eq_f_lo "Mod. Luma 3 band eq (3) Low freq (MHz)" 1.5 0.025 5.5 0.025
//#pragma parameter pn_modulator_luma_eq_f_hi "Mod. Luma 3 band eq (3) Hi freq (MHz)" 3.0 0.025 5.5 0.025
//#pragma parameter pn_modulator_luma_eq_g_lo "Mod. Luma 3 band eq (3) Low gain" 1.0 0.025 1.0 0.025
//#pragma parameter pn_modulator_luma_eq_g_mid "Mod. Luma 3 band eq (3) Mid gain" 0.125 0.025 1.0 0.025
//#pragma parameter pn_modulator_luma_eq_g_hi "Mod. Luma 3 band eq (3) High gain" 0.15 0.025 1.0 0.025
//#pragma parameter pn_modulator_luma_eq_off "Mod. Luma 3 band eq (3) offset (pixels)" 0.5 0 4 0.0125
//#pragma parameter pn_modulator_luma_eq_dist "Mod. Luma 3 band eq (3) max distance (% screen)" 20 5 40.0 0.25

#pragma parameter pn_modulator_chroma_filter_type "Mod. Chroma Bandpass Type" 0 -1 0 1
#pragma parameter pn_modulator_chroma_filter_width "Mod. Chroma Bandpass (Type 0) Half-Width" 3 0 30 0.25
#pragma parameter pn_modulator_chroma_filter_level "Mod. Chroma Bandpass (Type 0) Low Frequency (MHz)" 3.55 0.5 6.0 0.025
#pragma parameter pn_modulator_chroma_filter_level_diff "Mod. Chroma Bandpass (Type 0) High Frequency (MHz)" 3.6 0.5 6.0 0.025
//#pragma parameter pn_modulator_chroma_eq_f_lo "Mod. Chroma 3 band eq (1) Low freq (MHz)" 3.2 0.025 5.5 0.025
//#pragma parameter pn_modulator_chroma_eq_f_hi "Mod. Chroma 3 band eq (1) Hi freq (MHz)" 4.5 0.025 5.5 0.025
//#pragma parameter pn_modulator_chroma_eq_g_lo "Mod. Chroma 3 band eq (1) Low gain" 0.1 0.025 1.0 0.025
//#pragma parameter pn_modulator_chroma_eq_g_mid "Mod. Chroma 3 band eq (1) Mid gain" 1.0 0.025 1.0 0.025
//#pragma parameter pn_modulator_chroma_eq_g_hi "Mod. Chroma 3 band eq (1) High gain" 0.1 0.025 1.0 0.025
//#pragma parameter pn_modulator_chroma_eq_off "Mod. Chroma 3 band eq (3) offset (pixels)" 0.5 0 4 0.0125
//#pragma parameter pn_modulator_chroma_eq_dist "Mod. Chroma 3 band eq (1) max distance (% screen)" 20 5 40.0 0.25

#pragma parameter pn_comment_demod_filter "=== CRT Chroma/Luma Separation (a.k.a. comb filter) ===" 0 0 0 1
#pragma parameter pn_demodulator_luma_filter_type "Demodulator Luma Filter Type" 7 -1 8 1
#pragma parameter pn_demodulator_luma_test "Test Luma Filter (Make chroma = luma)" 0 0 2 1
#pragma parameter pn_demodulator_luma_test_threshold "Test Luma Filter Threshold" 0.2 0.01 0.5 0.01
#pragma parameter pn_demodulator_luma_filter_width "(Type 0) Lowpass Sinc Window Half-Width" 5 0 30 0.25
#pragma parameter pn_demodulator_luma_filter_level "(Type 0) Lowpass Sinc Cutoff Frequency (MHz)" 2.15 0.5 4.0 0.025
#pragma parameter pn_demodulator_luma_notch_width "Demod. Luma Bandstop (Type 1) Sinc Half-Width" 3 0 30 0.025
#pragma parameter pn_demodulator_luma_notch_lo "Demod. Luma Bandstop (Type 1) Sinc Low Frequency (MHz)" 3.55 0.5 40.0 0.025
#pragma parameter pn_demodulator_luma_notch_hi "Demod. Luma Bandstop (Type 1) Sinc High Frequency (MHz)" 3.60 0.025 40.0 0.025
#pragma parameter pn_demodulator_luma_notch_intensity "Demod. Luma Bandstop (Type 1) Filter Strength" 1.0 0.0 1.0 0.025
#pragma parameter pn_demodulator_luma_antihigh_width "Demod. Luma Anti-Highpass (Type 2) Sinc Half-Width" 2.5 0 30 0.025
#pragma parameter pn_demodulator_luma_antihigh_cancelfreq "Demod. Luma Anti-Highpass (Type 2) Cancel Freq (MHz)" 3.58 0.5 40.0 0.025
#pragma parameter pn_demodulator_luma_antihigh_cutofffreq "Demod. Luma Anti-Highpass (Type 2) Cutoff Freq (MHz)" 3.2 0.025 40.0 0.025
//#pragma parameter pn_demodulator_luma_radius "(Type 1) Gaussian Blur Radius" 4.5 0.1 15.0 0.1
//#pragma parameter pn_demodulator_luma_sigma "(Type 1) Gaussian Blur Sigma" 1.9 0.1 15.0 0.01
//#pragma parameter pn_demodulator_luma_int_dist "(2) Leaky Integrator Distance" 5 0 30 0.25
//#pragma parameter pn_demodulator_luma_int_off "(2) Leaky Integrator Offset" -1 -1 30 0.25
//#pragma parameter pn_demodulator_luma_int_rate "(2) Leaky Integrator Rate" 5.0 0.0 100.0 0.025
#pragma parameter pn_demodulator_luma_avg_comment "(Type 3) (No settings) Full-phase Integral" 0 0 0 1
#pragma parameter pn_demodulator_luma_echo_comment "(Type 4) (No settings) Half-phase two point avg." 0 0 0 1
#pragma parameter pn_demodulator_luma_comb2_comment "(Type 5) (No settings) Two line comb filter" 0 0 0 1
#pragma parameter pn_demodulator_luma_comb3_comment "(Type 6) (No settings) Three line comb filter" 0 0 0 1
#pragma parameter pn_demodulator_luma_sinc_preset "(7) Easy Sharpness (Lowpass Cutoff Rate)" 2.6 2.15 2.90 0.15
//#pragma parameter pn_demodulator_luma_eq_f_lo "Demod. Luma 3 band eq (3) Low freq (MHz)" 1.5 0.025 5.5 0.025
//#pragma parameter pn_demodulator_luma_eq_f_hi "Demod. Luma 3 band eq (3) Hi freq (MHz)" 3.0 0.025 5.5 0.025
//#pragma parameter pn_demodulator_luma_eq_g_lo "Demod. Luma 3 band eq (3) Low gain" 1.0 0.025 1.0 0.025
//#pragma parameter pn_demodulator_luma_eq_g_mid "Demod. Luma 3 band eq (3) Mid gain" 0.125 0.025 1.0 0.025
//#pragma parameter pn_demodulator_luma_eq_g_hi "Demod. Luma 3 band eq (3) High gain" 0.15 0.025 1.0 0.025
//#pragma parameter pn_demodulator_luma_eq_off "Demod. Luma 3 band eq (3) offset (pixels)" 0.5 0 4 0.0125
//#pragma parameter pn_demodulator_luma_eq_dist "Demod. Luma 3 band eq (3) max distance (% screen)" 20 5 40.0 0.25

#pragma parameter pn_demodulator_chroma_filter_type "Demod. Chroma Filter Type" 0 -1 4 1
#pragma parameter pn_demodulator_chroma_filter_width "Demod. Chroma Bandpass (Type 0) Half-Width" 5 0 30 0.25
#pragma parameter pn_demodulator_chroma_filter_level "Demod. Chroma Bandpass (Type 0) Low Frequency (MHz)" 3.55 0.5 6.0 0.025
#pragma parameter pn_demodulator_chroma_filter_level_diff "Demod. Chroma Bandpass (Type 0) High Frequency (MHz)" 3.6 0.5 6.0 0.025
#pragma parameter pn_demodulator_chroma_filter_echo_comment "(Type 1) (No settings) Half-phase two point avg." 0 0 0 1
#pragma parameter pn_demodulator_chroma_filter_comb2_comment "(Type 2) (No settings) Two line comb filter" 0 0 0 1
#pragma parameter pn_demodulator_chroma_filter_comb3_comment "(Type 3) (No settings) Three line comb filter" 0 0 0 1
#pragma parameter pn_demodulator_chroma_except "(Type 4) (No settings) Subtract filtered luma" 0 0 0 1
//#pragma parameter pn_demodulator_chroma_eq_f_lo "Demod. Chroma 3 band eq (1) Low freq (MHz)" 3.2 0.025 5.5 0.025
//#pragma parameter pn_demodulator_chroma_eq_f_hi "Demod. Chroma 3 band eq (1) Hi freq (MHz)" 4.5 0.025 5.5 0.025
//#pragma parameter pn_demodulator_chroma_eq_g_lo "Demod. Chroma 3 band eq (1) Low gain" 0.1 0.025 1.0 0.025
//#pragma parameter pn_demodulator_chroma_eq_g_mid "Demod. Chroma 3 band eq (1) Mid gain" 1.0 0.025 1.0 0.025
//#pragma parameter pn_demodulator_chroma_eq_g_hi "Demod. Chroma 3 band eq (1) High gain" 0.1 0.025 1.0 0.025
//#pragma parameter pn_demodulator_chroma_eq_off "Demod. Chroma 3 band eq (3) offset (pixels)" 0.5 0 4 0.0125
//#pragma parameter pn_demodulator_chroma_eq_dist "Demod. Chroma 3 band eq (1) max distance (% screen)" 20 5 40.0 0.25

#pragma parameter pn_demodulator_uv_filter_type "B-Y R-Y Filter Type" 1 1 2 1
#pragma parameter pn_demodulator_uv_filter_width "B-Y R-Y (0; Deprecated) Rectangular Filter Width" 1 1 10 1
#pragma parameter pn_demodulator_uv_sinc_width "B-Y R-Y (1) Sinc Window Width" 10 0 30 0.25
#pragma parameter pn_demodulator_uv_sinc_level "B-Y R-Y (1) Sinc Window Level" 6 0.025 10 0.025
#pragma parameter pn_demodulator_uv_int_dist "B-Y R-Y (2) Leaky Integrator Distance" 15 0 30 0.25
#pragma parameter pn_demodulator_uv_int_off "B-Y R-Y (2) Leaky Integrator Offset (negative=Auto)" -1 -1 30 0.25
#pragma parameter pn_demodulator_uv_int_rate "B-Y R-Y (2) Leaky Integrator Rate" 25 0.0 100.0 0.025

#pragma parameter pn_comment_demod_std "=== CRT Jungle Chip Chroma Demodulation Axes ===" 0 0 0 1
#pragma parameter pn_demodulator_std "R-Y/G-Y/B-Y preset: Rec. 601, Rec. 709, 2*JP, 5*US, Custom" 8 0 9 1
#pragma parameter pn_demodulator_std_defaults "Auto-sync Tint/Color: Off; Avg. Bars; Match red; Eyeballed" 2 -1 2 1
#pragma parameter pn_demodulator_r_off "Custom R-Y offset" 112 90 130 1
#pragma parameter pn_demodulator_r_amp "Custom R-Y gain" 0.84 0.0 1.00 0.01
#pragma parameter pn_demodulator_g_off "Custom G-Y offset" 235 200 300 1
#pragma parameter pn_demodulator_g_amp "Custom G-Y gain" 0.33 0.0 1.00 0.01
#pragma parameter pn_commment_b "= (B-Y offset=0, gain=1.0) =" 0 0 0 1

#pragma parameter pn_comment_knobs "=== CRT End User Color Knobs ===" 0 0 0 1
#pragma parameter pn_auto_contrast "Auto Contrast (Recommended) (Does not work with Grade EOTF)" 1 0 1 1
#pragma parameter pn_knob_contrast "Contrast (Picture)" 0.75 0 2 0.025
#pragma parameter pn_knob_brightness "Brightness (Black Level) (default 0.1 for BT.1886 except Grade)" 0.15 -0.5 0.5 0.01
#pragma parameter pn_knob_saturation "Color (Saturation)" 1.0 0 5 0.025
#pragma parameter pn_knob_tint "Tint (Hue Rotation)" 0 -45 45 0.5

#pragma parameter pn_comment_smearing "=== CRT Glitches (Should leave these at defaults) ===" 0 0 0 1
#pragma parameter pn_rgb_smear_enable "Enable RGB Smearing (for *SEVERELY* worn-out CRTs)" 0 0 1 1
#pragma parameter pn_rgb_smear_clamp "RGB Clamp Level (any value above this becomes equal to this)" 1.5 1.0 3.0 0.05
#pragma parameter pn_rgb_smear_rate "RGB Smear Level (after clamping, anything above this smears)" 1.15 1.0 3.0 0.05
#pragma parameter pn_rgb_smear_limit "Max Smear Detection Distance (% of screen)" 30 0 100 0.25
#pragma parameter pn_rgb_smear_res "Smear Resolution (Higher is more intense but more accurate)" 1 1 3 1

#pragma parameter pn_comment_phosphor "=== CRT Gamma and Phosphor Gamut ===" 0 0 0 1
#pragma parameter pn_gamma_type "EOTF: Grade BT.1886 | BT.1886 | Power | sRGB | Patchy BT.1886" 4 0 4 1
#pragma parameter pn_g_CRT_l        "Grade BT.1886 black lift fix approximate gamma"                  2.50   2.30  2.60 0.01
#pragma parameter pn_power_gamma "Power gamma" 2.4 1.5 3.5 0.01
#pragma parameter pn_blackfix_patchy "Patchy BT.1886 brightness override" 0.0 0.0 1.0 0.025

#endif // __patchy_ntsc_inc_params_inc__

