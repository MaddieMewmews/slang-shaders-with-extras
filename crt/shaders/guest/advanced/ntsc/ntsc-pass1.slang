#version 450

// NTSC-Adaptive Pass1
// based on Themaister's NTSC shader


layout(push_constant) uniform Push
{
   vec4 OutputSize;
   vec4 OriginalSize;
   vec4 SourceSize;
   uint FrameCount;
   float quality, ntsc_sat, cust_fringing, cust_artifacting, ntsc_bright, ntsc_fields, ntsc_phase, ntsc_gamma, ntsc_rainbow1, ntsc_taps, auto_res;
   float ntsc_charp;
   float ntsc_charp3;
   float speedup;
   float ntsc_dith;
   float nscale;
   float ntsc_samp;
   float ntsc_fonts;   
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma parameter ntsc-row0 "------------------------------------------------" 0.0 0.0 0.0 1.0
#pragma parameter auto_res     "          SNES/Amiga Hi-Res Auto Mode" 0.0 0.0 1.0 1.0
#pragma parameter filter_res   "          Horizontal Filtering Resolution" 1.0 0.5 8.0 0.05
#pragma parameter speedup      "          Speedup w. higher Internal Res." 1.0 1.0 4.0 1.0
#pragma parameter ntsc_samp    "          Hi-Res Sampling Behaviour: Default | Old" 1.0 1.0 2.0 1.0
#pragma parameter ntsc-row1 "------------------------------------------------" 0.0 0.0 0.0 1.0
#pragma parameter quality "INFO --> A&F Values: Svideo = 0.0 | Composite = 1.0 | RF = 2.0" 0.0 0.0 0.0 1.0
#pragma parameter cust_artifacting "NTSC Artifacting Value" 1.0 0.0 5.0 0.1
#pragma parameter cust_fringing "NTSC Fringing Value" 1.0 0.0 5.0 0.1
#pragma parameter ntsc-row2 "------------------------------------------------" 0.0 0.0 0.0 1.0
#pragma parameter ntsc_fields "NTSC Merge Fields: Auto | NO | YES" -1.0 -1.0 1.0 1.0
#pragma parameter ntsc_phase  "NTSC Phase: Auto | 2 phase | 3 phase | Mixed | PCE" 1.0 1.0 5.0 1.0
#pragma parameter nscale      "NTSC Filter (Resolution) Scaling" 1.0 0.20 5.0 0.05
#pragma parameter ntsc_dith   "NTSC De-Dith: 0:OFF | 1-2:CB+Bar | 3:CB+Bar(Fonts) | 4:CB-Mixed" 0.0 0.0 4.0 1.0
#pragma parameter ntsc_fonts  "NTSC Preserve Fonts (0.25 = OFF)" 0.25 0.25 0.75 0.05
#pragma parameter ntsc_sat    "NTSC Color Saturation" 1.0 0.0 2.0 0.01
#pragma parameter ntsc_bright "NTSC Brightness" 1.0 0.0 1.5 0.01
#pragma parameter ntsc_gamma  "NTSC Filtering Gamma Correction" 1.0 0.25 2.5 0.025
#pragma parameter ntsc_rainbow1 "NTSC Coloring/Rainbow Effect (2-phase)" 0.0 0.0 3.0 1.0
#pragma parameter ntsc-row3 "------------------------------------------------" 0.0 0.0 0.0 1.0
#pragma parameter ntsc_taps   "NTSC # of Taps (Filter Width)" 32.0 6.0 32.0 1.0
#pragma parameter ntsc_charp  "NTSC Preserve 'Edge' Colors 2-phase" 0.0 0.0 10.0 0.50
#pragma parameter ntsc_charp3 "NTSC Preserve 'Edge' Colors 3-phase" 0.0 0.0 10.0 0.50

float FrameCount = float(params.FrameCount);
#define speedup params.speedup
#define PI 3.14159265
#define ntsc_dith params.ntsc_dith

float smothstep (float e0, float e1, float x)
{
   return clamp((x - e0) / (e1 - e0), 0.0, 1.0);
}

vec3 smstep (vec3 e0, vec3 e1, vec3 x)
{
   return clamp((x - e0) / (e1 - e0), 0.0, 1.0);
}


#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 pix_no;
layout(location = 2) out float phase;
layout(location = 3) out float BRIGHTNESS;
layout(location = 4) out float SATURATION;
layout(location = 5) out float FRINGING;
layout(location = 6) out float ARTIFACTING;
layout(location = 7) out float CHROMA_MOD_FREQ;
layout(location = 8) out float MERGE;
layout(location = 9) out float MIT;

void main()
{
	gl_Position = global.MVP * Position;
	vTexCoord = TexCoord * vec2(speedup, 1.0);

	float OriginalSize = (params.OriginalSize.x < 450.0) ? params.OriginalSize.x : params.OriginalSize.x / max(round(params.OriginalSize.x / 300.0), 1.0);
	phase = (params.ntsc_phase < 1.5) ? ((OriginalSize > 300.0 || (params.OriginalSize.x > 400.0 && params.OriginalSize.y > 250.0)) ? 2.0 : 3.0) : ((params.ntsc_phase > 2.5) ? 3.0 : 2.0);
	if (params.ntsc_phase == 4.0) phase = 3.0; else if (params.ntsc_phase == 5.0) phase = 2.0;
	float ntsc_sizex = (params.OriginalSize.x < 400.0) ? params.OriginalSize.x : (phase == 2.0) ? 320.0 : 256.0;
	ntsc_sizex = (params.ntsc_samp < 1.5) ? ntsc_sizex : params.OriginalSize.x;
	float ntsc_sizey = params.OriginalSize.y / max(round(params.OriginalSize.y / 220.0), 1.0);
	pix_no = vTexCoord * vec2(ntsc_sizex,ntsc_sizey) * vec2(4.0, 1.0);
	pix_no.y = round(pix_no.y);
	
	CHROMA_MOD_FREQ = (phase == 2.0 && params.ntsc_phase != 5.0) ? (4.0 * PI / 15.0) : ((OriginalSize <= 300.0 || phase == 3.0) ? (PI / 3.0) : (PI/2.0));
	ARTIFACTING = params.cust_artifacting;
	FRINGING = params.cust_fringing;
	SATURATION = params.ntsc_sat;
	BRIGHTNESS = params.ntsc_bright;
	MERGE = 0.0;
	if (params.ntsc_fields == -1.0 && phase == 3.0) MERGE = 1.0;
	else if (params.ntsc_fields ==  0.0) MERGE = 0.0;
	else if (params.ntsc_fields ==  1.0) MERGE = 1.0;	
	MIT = params.ntsc_taps;
	MIT = smothstep(16.0, 8.0, MIT) * 0.325;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 pix_no;
layout(location = 2) in float phase;
layout(location = 3) in float BRIGHTNESS;
layout(location = 4) in float SATURATION;
layout(location = 5) in float FRINGING;
layout(location = 6) in float ARTIFACTING;
layout(location = 7) in float CHROMA_MOD_FREQ;
layout(location = 8) in float MERGE;
layout(location = 9) in float MIT;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

mat3 mix_mat = mat3(BRIGHTNESS, FRINGING, FRINGING, ARTIFACTING, 2.0*SATURATION, 0.0, ARTIFACTING, 0.0, 2.0*SATURATION);


const mat3 yiq2rgb_mat = mat3(
   1.0, 0.956, 0.6210,
   1.0, -0.2720, -0.6474,
   1.0, -1.1060, 1.7046);

vec3 yiq2rgb(vec3 yiq)
{
   return yiq * yiq2rgb_mat;
}

const mat3 yiq_mat = mat3(
      0.2989, 0.5870, 0.1140,
      0.5959, -0.2744, -0.3216,
      0.2115, -0.5229, 0.3114
);

vec3 rgb2yiq(vec3 col)
{
   return col * yiq_mat;
}

float get_luma(vec3 c)
{
	return dot(c, vec3(0.2989, 0.5870, 0.1140));
}

void main()
{
if (vTexCoord.x > 1.0) FragColor = 0.0.xxxx; else
{  
   vec3 col = texture(Source, vTexCoord).rgb;
 
   vec3 yiq = rgb2yiq(col);
   yiq.x = pow(yiq.x, params.ntsc_gamma);
   float lum = yiq.x; 

   vec3 tmp =  yiq;
   vec3 yiq2 = yiq;
   vec3 yiqs = yiq;
   vec3 yiqz = yiq;

   float res = params.nscale;
   float dd = 1.0;
   float linres = 0.0;
   vec2 TexD = (floor(vTexCoord * params.OriginalSize.xy) + 0.5)*params.OriginalSize.zw;   
   
   if (((ntsc_dith > 0.5 && params.nscale > 1.025) || (params.ntsc_fonts > 0.255)) && params.OriginalSize.y < 300.0 && (phase == 2.0 || params.ntsc_phase > 3.5))
   {
      vec2 xx = vec2(params.OriginalSize.z, 0.0);
      vec2 yy = vec2(0.0, params.OriginalSize.w);
      vec3 ca = vec3(get_luma(texture(Source, TexD - xx - xx - yy).rgb), get_luma(texture(Source, TexD - xx - xx).rgb), get_luma(texture(Source, TexD - xx - xx + yy).rgb));
      vec3 c0 = vec3(get_luma(texture(Source, TexD - xx - yy).rgb), get_luma(texture(Source, TexD - xx).rgb), get_luma(texture(Source, TexD - xx + yy).rgb));
      vec3 c1 = vec3(get_luma(texture(Source, TexD - yy).rgb), get_luma(texture(Source, TexD).rgb), get_luma(texture(Source, TexD +yy).rgb));
      vec3 c2 = vec3(get_luma(texture(Source, TexD + xx - yy).rgb), get_luma(texture(Source, TexD + xx).rgb), get_luma(texture(Source, TexD + xx + yy).rgb));
      vec3 cb = vec3(get_luma(texture(Source, TexD + xx + xx - yy).rgb), get_luma(texture(Source, TexD + xx + xx).rgb), get_luma(texture(Source, TexD + xx + xx + yy).rgb));
	  vec3 line0  = step(min(abs(c1-c0),abs(c2-c1)), 0.01.xxx);
           line0  =	max(step(abs(c1-c0)+abs(c2-c1), abs(c0-c2)),line0);  
      vec3 line1  = max(step(min(abs(ca-c0),abs(c2-cb)), 0.01.xxx), line0);
      vec3 line2  = max(step(min(abs(ca-c2),abs(c0-cb)), 0.01.xxx), line1);
      vec3 line3  = max(step(max(abs(ca-c0),abs(c2-cb)), 0.15.xxx), line2);	  
	  vec3 line4  = max(smstep(0.075.xxx, 0.35*max(c1,1.0-c1), max(min(abs(c1-cb),abs(c0-c2)),min(abs(c1-ca),abs(c0-c2)))), line3);
      vec3 line5  = step(min(max(abs(c0-c2),abs(c1-ca)),max(abs(c0-c2),abs(c1-cb))), 0.025.xxx);
	  float dth   = step(max(abs(c1.y-c0.y),abs(c1.y-c2.y)), 0.25);
	  vec3 linebar = mix(line3, line0, line5); if (ntsc_dith == 2.0 || ntsc_dith == 3.0) linebar = line0;
	  vec3 linecb = mix(mix(line3, line4, dth), line0, line5);

	  float line6 = dth*min(step(min(abs(c1.y-c1.x),abs(c1.y-c1.z)),0.03), max(step(max(abs(c0.y-c0.x),abs(c0.y-c0.z)),0.03) , step(max(abs(c2.y-c2.x),abs(c2.y-c2.z)),0.03)));
	  linecb.y = (min(max(abs(c1.y-c1.x),abs(c0.y-c0.x)), max(abs(c1.y-c1.x),abs(c2.y-c2.x))) < 0.025) ? max(linecb.y, dth) : linecb.y;
	  linecb.y = (min(max(abs(c1.y-c1.z),abs(c0.y-c0.z)), max(abs(c1.y-c1.z),abs(c2.y-c2.z))) < 0.025) ? max(linecb.y, dth) : linecb.y;	  
	  
	  linebar.y = min(linebar.y, max(linebar.x,linebar.z));
	  linecb.y  = max(linecb.y, line6);

      linres = (ntsc_dith < 3.5) ? linebar.y : linecb.y;

	  float nd = max(res-1.0, 0.0);
      dd = 1.0 + (1.0-linres) * nd;
	  res /= dd;

      vec3 lineb = 0.0.xxx;
	  lineb.x = float(abs(c0.x-c2.x) < 0.035 && (abs(c1.x-ca.x) < 0.035 || abs(c1.x-cb.x) < 0.035) && max(abs(ca.x-c0.x),abs(cb.x-c2.x)) > 0.035); 
	  lineb.y = float(abs(c0.y-c2.y) < 0.035 && (abs(c1.y-ca.y) < 0.035 || abs(c1.y-cb.y) < 0.035) && min(abs(c0.y-c0.x),abs(c0.y-c0.z)) < 0.035); 
	  lineb.z = float(abs(c0.z-c2.z) < 0.035 && (abs(c1.z-ca.z) < 0.035 || abs(c1.z-cb.z) < 0.035) && max(abs(ca.z-c0.z),abs(cb.z-c2.z)) > 0.035);
	  lineb.y = min(lineb.y, max(lineb.x,lineb.z)) * (1.0-linebar.y);
	  
      linres = 0.25*linebar.y + 0.5*linecb.y + 2.0*lineb.y;
   }

if (MERGE > 0.5)
{
   float chroma_phase2 = (phase < 2.5) ? PI * (mod(pix_no.y, 2.0) + mod(FrameCount+1.0, 2.0)) : 0.6667 * PI * (mod(pix_no.y, 3.0) + mod(FrameCount+1.0, 2.0));
   float mod_phase2 = chroma_phase2 + pix_no.x * CHROMA_MOD_FREQ;
   float i_mod2 = cos(mod_phase2);
   float q_mod2 = sin(mod_phase2);
   yiq2.yz *= vec2(i_mod2, q_mod2); // Modulate.
   yiq2 *= mix_mat; // Cross-talk.
   yiq2.yz *= vec2(i_mod2, q_mod2); // Demodulate.
   yiq2.yz = mix(yiq2.yz, tmp.yz, MIT);   

   if (res > 1.025)
   {
      mod_phase2 = chroma_phase2 + pix_no.x * CHROMA_MOD_FREQ * res;
      i_mod2 = cos(mod_phase2);
      q_mod2 = sin(mod_phase2);
      yiqs.yz *= vec2(i_mod2, q_mod2); // Modulate.
      yiq2.x = dot(yiqs, mix_mat[0]);  // Cross-talk.
   }
}
   
   float chroma_phase = (phase < 2.5) ? PI * (mod(pix_no.y, 2.0) + mod(FrameCount, 2.0)) : 0.6667 * PI * (mod(pix_no.y, 3.0) + mod(FrameCount, 2.0));
   float mod_phase = chroma_phase + pix_no.x * CHROMA_MOD_FREQ;
   float i_mod = cos(mod_phase);
   float q_mod = sin(mod_phase);
   yiq.yz *= vec2(i_mod, q_mod); // Modulate.
   yiq *= mix_mat; // Cross-talk.
   yiq.yz *= vec2(i_mod, q_mod); // Demodulate.
   yiq.yz = mix(yiq.yz, tmp.yz, MIT);
   
    if (res > 1.025)
   {
      mod_phase = chroma_phase + pix_no.x * CHROMA_MOD_FREQ * res;
      i_mod = cos(mod_phase);
      q_mod = sin(mod_phase);
      yiqz.yz *= vec2(i_mod, q_mod); // Modulate.
      yiq.x = dot(yiqz, mix_mat[0]); // Cross-talk.
   }

      
   if (params.ntsc_phase == 4.0)
   {
      yiq.x = lum; yiq2.x = lum;
   }

   if (MERGE > 0.5) { if (params.ntsc_rainbow1 < 0.5 || phase > 2.5) yiq = 0.5*(yiq + yiq2); else yiq.x = 0.5*(yiq.x + yiq2.x); }
   
   FragColor = vec4(yiq, linres);
}

} 
