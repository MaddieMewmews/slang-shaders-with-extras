#version 450

// NTSC-Adaptive Pass2
// based on Themaister's NTSC shader


layout(push_constant) uniform Push
{
   vec4 OutputSize;
   vec4 OriginalSize;
   vec4 SourceSize;
   float ntsc_phase;
   float ntsc_ring;
   float ntsc_cscale;
   float ntsc_cscale1;
   float ntsc_taps;
   float auto_res;
   float ntsc_charp;
   float ntsc_charp3;
   float speedup;
   float nscale;
   float ntsc_dith;
   float ntsc_samp;
   float ntsc_gamma;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma parameter auto_res  "          SNES/Amiga Hi-Res Auto Mode" 0.0 0.0 1.0 1.0
#pragma parameter speedup   "          Speedup w. higher Internal Res." 1.0 1.0 4.0 1.0
#pragma parameter ntsc_samp "          Hi-Res Sampling Behaviour: Default | Old" 1.0 1.0 2.0 1.0
#pragma parameter ntsc_gamma   "NTSC Filtering Gamma Correction" 1.0 0.25 2.5 0.025
#pragma parameter ntsc_phase   "NTSC Phase: Auto | 2 phase | 3 phase | Mixed | PCE" 1.0 1.0 5.0 1.0
#pragma parameter nscale       "NTSC Filter (Resolution) Scaling" 1.0 0.20 5.0 0.05
#pragma parameter ntsc_dith    "NTSC De-Dith: 0:OFF | 1-2:CB+Bar | 3:CB+Bar(Fonts) | 4:CB-Mixed" 0.0 0.0 4.0 1.0
#pragma parameter ntsc_taps    "NTSC # of Taps (Filter Width)" 32.0 6.0 32.0 1.0
#pragma parameter ntsc_cscale  "NTSC Chroma Scaling / Bleeding (2-phase)" 1.0 0.20 5.00 0.05
#pragma parameter ntsc_cscale1 "NTSC Chroma Scaling / Bleeding (3-phase)" 1.0 0.20 2.50 0.05
#pragma parameter ntsc_charp   "NTSC Preserve 'Edge' Colors 2-phase" 0.0 0.0 10.0 0.50
#pragma parameter ntsc_charp3  "NTSC Preserve 'Edge' Colors 3-phase" 0.0 0.0 10.0 0.50
#pragma parameter ntsc-row4 "------------------------------------------------" 0.0 0.0 0.0 1.0
#pragma parameter ntsc_ring    "NTSC Anti-Ringing" 0.5 0.0 1.0 0.10

#define speedup params.speedup
#define nscale params.nscale
#define ntsc_dith params.ntsc_dith

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float phase;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord + vec2(0.5 / speedup * params.OriginalSize.z/4.0, 0.0);    // Compensate for decimate-by-2.
   float OriginalSize = (params.OriginalSize.x < 450.0) ? params.OriginalSize.x : params.OriginalSize.x / max(round(params.OriginalSize.x / 300.0), 1.0);
   phase = (params.ntsc_phase < 1.5) ? ((OriginalSize > 300.0 || (params.OriginalSize.x > 400.0 && params.OriginalSize.y > 250.0)) ? 2.0 : 3.0) : ((params.ntsc_phase > 2.5) ? 3.0 : 2.0);
   if (params.ntsc_phase == 4.0) phase = 3.0; else if (params.ntsc_phase == 5.0) phase = 2.0;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float phase;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D PrePass0;



vec3 fetch_offset(vec3 dx)
{
   return vec3(texture(Source, vTexCoord + dx.xz).x + texture(Source, vTexCoord - dx.xz).x, texture(Source, vTexCoord + dx.yz).yz + texture(Source, vTexCoord - dx.yz).yz);
}

float get_luma(vec3 c)
{
	return dot(c, vec3(0.2989, 0.5870, 0.1140));
}

float smothstep (float e0, float e1, float x)
{
   return clamp((x - e0) / (e1 - e0), 0.0, 1.0);
}

vec3 smstep (vec3 e0, vec3 e1, vec3 x)
{
   return clamp((x - e0) / (e1 - e0), 0.0, 1.0);
}

const int TAPS_2_phase = 32;
const int TAPS_3_phase = 24;


const float luma_filter_2_phase[33] = float[33](
  -0.000174844,
  -0.000205844,
  -0.000149453,
  -0.000051693,
   0.000000000,
  -0.000066171,
  -0.000245058,
  -0.000432928,
  -0.000472644,
  -0.000252236,
   0.000198929,
   0.000687058,
   0.000944112,
   0.000803467,
   0.000363199,
   0.000013422,
   0.000253402,
   0.001339461,
   0.002932972,
   0.003983485,
   0.003026683,
  -0.001102056,
  -0.008373026,
  -0.016897700,
  -0.022914480,
  -0.021642347,
  -0.028863273,
   0.027271957,
   0.054921920,
   0.098342579,
   0.139044281,
   0.168055832,
   0.178571429);


const float chroma_filter_2_phase[33] = float[33](
   1.00000,
   2.00000,
   3.00000,
   4.00000,
   5.00000,
   6.00000,
   7.00000,
   8.00000,
   9.00000,
  10.00000,
  11.00000,
  12.00000,
  13.00000,
  14.00000,
  15.00000,
  16.00000,
  17.00000,
  18.00000,
  19.00000,
  20.00000,
  21.00000,
  22.00000,
  23.00000,
  24.00000,
  25.00000,
  26.00000,
  27.00000,
  28.00000,
  29.00000,
  30.00000,
  31.00000,
  32.00000,
  33.00000);

const float chroma_filter_3_phase[33] = float[33](
   0.000000000,
   0.000000000,
   0.000000000,
   0.000000000,
   0.000000000,
   0.000000000,
   0.000000000,
   0.000000000,
  -0.000118847,
  -0.000271306,
  -0.000502642,
  -0.000930833,
  -0.001451013,
  -0.002064744,
  -0.002700432,
  -0.003241276,
  -0.003524948,
  -0.003350284,
  -0.002491729,
  -0.000721149,
   0.002164659,
   0.006313635,
   0.011789103,
   0.018545660,
   0.026414396,
   0.035100710,
   0.044196567,
   0.053207202,
   0.061590275,
   0.068803602,
   0.074356193,
   0.077856564,
   0.079052396);

void main()
{

if (vTexCoord.x * speedup > (1.00325)) discard;


float luma_filter_3_phase[33] = float[33](
   0.000000000,
   0.000000000,
   0.000000000,
   0.000000000,
   0.000000000,
   0.000000000,
   0.000000000,
   0.000000000,
  -0.000012020,
  -0.000022146,
  -0.000013155,
  -0.000012020,
  -0.000049979,
  -0.000113940,
  -0.000122150,
  -0.000005612,
   0.000170516,
   0.000237199,
   0.000169640,
   0.000285688,
   0.000984574,
   0.002018683,
   0.002002275,
  -0.005909882,
  -0.012049081,
  -0.018222860,
  -0.022606931,
   0.002460860,
   0.035868225,
   0.084016453,
   0.135563500,
   0.175261268,
   0.220176552);
 
   float res = nscale;
   vec2 TexD = (floor(vTexCoord * params.OriginalSize.xy) + 0.5)*params.OriginalSize.zw;
   float dd = 1.0;
   
   if ((ntsc_dith > 0.5) && (nscale > 1.025) && params.OriginalSize.y < 300.0 && (phase == 2.0 || params.ntsc_phase > 3.5))
   {
      vec2 xx = vec2(params.OriginalSize.z, 0.0);
      vec2 yy = vec2(0.0, params.OriginalSize.w);
      vec3 cx = vec3(get_luma(texture(PrePass0, TexD - 3.0*xx - yy).rgb), get_luma(texture(PrePass0, TexD - 3.0*xx).rgb), get_luma(texture(PrePass0, TexD - 3.0*xx + yy).rgb));      
	  vec3 ca = vec3(get_luma(texture(PrePass0, TexD - xx - xx - yy).rgb), get_luma(texture(PrePass0, TexD - xx - xx).rgb), get_luma(texture(PrePass0, TexD - xx - xx + yy).rgb));
      vec3 c0 = vec3(get_luma(texture(PrePass0, TexD - xx - yy).rgb), get_luma(texture(PrePass0, TexD - xx).rgb), get_luma(texture(PrePass0, TexD - xx + yy).rgb));
      vec3 c1 = vec3(get_luma(texture(PrePass0, TexD - yy).rgb), get_luma(texture(PrePass0, TexD).rgb), get_luma(texture(PrePass0, TexD +yy).rgb));
      vec3 c2 = vec3(get_luma(texture(PrePass0, TexD + xx - yy).rgb), get_luma(texture(PrePass0, TexD + xx).rgb), get_luma(texture(PrePass0, TexD + xx + yy).rgb));
      vec3 cb = vec3(get_luma(texture(PrePass0, TexD + xx + xx - yy).rgb), get_luma(texture(PrePass0, TexD + xx + xx).rgb), get_luma(texture(PrePass0, TexD + xx + xx + yy).rgb));
      vec3 cy = vec3(get_luma(texture(PrePass0, TexD + 3.0*xx - yy).rgb), get_luma(texture(PrePass0, TexD + 3.0*xx).rgb), get_luma(texture(PrePass0, TexD + 3.0*xx + yy).rgb));
      vec3 line0  = step(min(abs(c1-c0),abs(c2-c1)), 0.25*abs(c0-c2));
           line0  =	max(step(abs(c1-c0)+abs(c2-c1),  0.25*abs(c0-c2)),line0);
           line0  = max(step(abs(cx-ca)+abs(c2-cb),  0.025.xxx), line0); line0  = max(step(abs(cy-cb)+abs(c0-ca), 0.025.xxx), line0);
	  vec3 line1  = max(step(min(abs(ca-c0),abs(c2-cb)), 0.025.xxx), line0);
      vec3 line2  = max(step(min(abs(ca-c2),abs(c0-cb)), 0.025.xxx), line1);
      vec3 line3  = max(step(max(abs(ca-c0),abs(c2-cb)), 0.15.xxx), line2);	  
	  vec3 line4  = max(smstep(0.075.xxx, 0.35*max(c1,1.0-c1), max(min(abs(c1-cb),abs(c0-c2)),min(abs(c1-ca),abs(c0-c2)))), line3);

      vec3 line5  = step(min(max(abs(c0-c2),abs(c1-ca)),max(abs(c0-c2),abs(c1-cb))), 0.025.xxx);
      float dth   = smothstep(0.24, 0.25, max(abs(c1.y-c0.y),abs(c1.y-c2.y)));
      vec3 linebar = mix(line3, line0, line5);
      vec3 linecb = mix(mix(line3, line4, dth), line0, line5);
	  float line6 = dth*min(step(min(abs(c1.y-c1.x),abs(c1.y-c1.z)),0.5*max(abs(c1.y-c0.y),abs(c1.y-c2.y))), max(step(max(abs(c0.y-c0.x),abs(c0.y-c0.z)),0.5*max(abs(c0.y-ca.y),abs(c0.y-c1.y))) , step(max(abs(c2.y-c2.x),abs(c2.y-c2.z)),0.5*max(abs(c2.y-c1.y),abs(c2.y-cb.y)))));
	  linecb.y = (min(max(abs(c1.y-c1.x),abs(c0.y-c0.x)), max(abs(c1.y-c1.x),abs(c2.y-c2.x))) < 0.025) ? max(linecb.y, dth) : linecb.y;
      linecb.y = (min(max(abs(c1.y-c1.z),abs(c0.y-c0.z)), max(abs(c1.y-c1.z),abs(c2.y-c2.z))) < 0.025) ? max(linecb.y, dth) : linecb.y;	  
      linebar.y = min(linebar.y, max(linebar.x,linebar.z));
      linecb.y  = max(linecb.y, line6);
	  
      float linres = (ntsc_dith < 3.5) ? linebar.y : linecb.y;
    
   if (ntsc_dith == 2.0 || ntsc_dith == 3.0)
   {   
	  float mn = 1.0; float mx = 0.0; float cbi = 0.0; float bri = 0.0; float b1 = 0.0; float b2 = 0.0; float sbi = 0.0;

      float tmp = 0.0; float cmp = 0.0;
      for (float i = -1.0; i <= 1.0; i++) 
	     for (float j = -1.0; j <= 1.0; j++)
	     {
		 	  if (fract(texture(Source, TexD + i*xx + j*yy).a) < 0.25) { tmp = get_luma(texture(PrePass0, TexD  + i*xx + j*yy).rgb); mn = min(mn, tmp); mx = max(mx,tmp); }
		 }
      
	  float ii[4] = float[4] (3.0,2.0,2.0,1.0);
	  
      for (float j = -3.0; j <= 3.0; j++)
         for (float i = -ii[int(abs(j))]; i <= ii[int(abs(j))]; i++)
	     {
		 	  tmp = get_luma(texture(PrePass0, TexD + i*xx + j*yy).rgb);
			  cmp = texture(Source, TexD  + i*xx + j*yy).a; float fmp = fract(cmp);
			  bool lsame = (abs(tmp-mn) < 0.025 ||  abs(tmp-mx) < 0.025);
			  if (fmp > 0.65 && lsame ) cbi++;
			  if (cmp < 0.25 && !lsame) bri++;
              if (cmp > 1.50 && lsame ) sbi++;
		 }
	  
      for (float i = 0.0; i < 14.0; i++) {
	     float sum1 = fract(2.0*texture(Source, TexD - i*yy).a) + fract(2.0*texture(Source, TexD - i*yy -xx).a) + fract(2.0*texture(Source, TexD - i*yy+xx).a); sum1 = max(1.5-sum1,0.0); if (sum1 > 0.75) b1++; else break; }
      for (float i = 1.0; i < 14.0; i++) {
	     float sum2 = fract(2.0*texture(Source, TexD + i*yy).a) + fract(2.0*texture(Source, TexD + i*yy -xx).a) + fract(2.0*texture(Source, TexD + i*yy+xx).a); sum2 = max(1.5-sum2,0.0); if (sum2 > 0.75) b2++; else break; }
	  
	  if (((cbi > bri) && (b1+b2) < 14.0) || (b1+b2) < 3.0) linres = linecb.y;
	  
	  if ((ntsc_dith == 2.0) && linres == linecb.y) if(sbi > 0.5*cbi || sbi < bri) linres = linebar.y;
   }
	  float nd = max(res-1.0, 0.0);
      dd = 1.0 + (1.0-linres) * nd;
	  res /= dd;
   }

   float ntsc_sizex = (params.ntsc_samp > 1.5) ? params.OriginalSize.x : ((params.OriginalSize.x < 450.0) ? params.OriginalSize.x : (phase == 2.0) ? 320.0 : 256.0);
   vec2 one_x = 0.25 / ntsc_sizex.xx;
   one_x.x = one_x.x / res / speedup;
   one_x.y = one_x.y / speedup;
   
   vec3 signal = vec3(0.0);
   if (params.ntsc_phase > 3.5) { luma_filter_3_phase = luma_filter_2_phase; }

   float offset = 0.0; int i = 0; float j = 0.0;
   vec3 wsum = 0.0.xxx;
   vec3 sums = wsum;
   vec3 tmp  = wsum;  

   if(phase < 2.5)
   {
      one_x.y = one_x.y/params.ntsc_cscale;
      vec3 dx = vec3(one_x.x, one_x.y, 0.0);
      float mit = 1.0;
      float iloop = params.ntsc_taps;
      iloop = max(iloop, 8.0); mit = 1.0 + 0.04*pow(smothstep(16.0, 8.0, iloop), 0.5);
      vec3 dx1 = dx; dx.x*=mit;
      int loopstart = int(32.0 - iloop);
	  int j = loopstart;
	  
      for (i = loopstart; i < 32; i++)
      {
         offset = float(i-loopstart); dx1.xy = (offset - iloop)*dx.xy;
         j = i - loopstart;
		 sums = fetch_offset(dx1);
         tmp = vec3(luma_filter_2_phase[i], chroma_filter_2_phase[j].xx);
         wsum = wsum + tmp;
         signal += sums * tmp;
      }
      j = int(iloop);
	  tmp = vec3(luma_filter_2_phase[TAPS_2_phase], chroma_filter_2_phase[j], chroma_filter_2_phase[j]);
      wsum = wsum + wsum + tmp;
      signal += texture(Source, vTexCoord).xyz * tmp;
      signal = signal / wsum;
   }
   else
   {
      one_x.y = one_x.y/params.ntsc_cscale1;
      vec3 dx = vec3(one_x.x, one_x.y, 0.0);
      float mit = 1.0;
      float iloop = min(params.ntsc_taps, TAPS_3_phase);
      if (params.ntsc_phase > 3.5) { iloop = max(iloop, 8.0); mit = 1.0 + 0.04*pow(smothstep(16.0, 8.0, iloop), 0.5); }
      vec3 dx1 = dx; dx.x*=mit;
      int loopstart = int(32.0 - iloop);
	  
      for (i = loopstart; i < 32; i++)
      {
         offset = float(i-loopstart); dx1.xy = (offset - iloop)*dx.xy;
         sums = fetch_offset(dx1);
         tmp = vec3(luma_filter_3_phase[i], chroma_filter_3_phase[i].xx);
         wsum = wsum + tmp;
         signal += sums * tmp;
      }
      tmp = vec3(luma_filter_3_phase[TAPS_2_phase], chroma_filter_3_phase[TAPS_2_phase], chroma_filter_3_phase[TAPS_2_phase]);
      wsum = wsum + wsum + tmp;
      signal += texture(Source, vTexCoord).xyz * tmp;
      signal = signal / wsum;
   }

   signal.x = clamp(signal.x, 0.0, 1.0);

   if (params.ntsc_ring > 0.05)
   {
      vec2 dx = vec2(params.OriginalSize.z / min(res, 1.0) / speedup, 0.0);
      float a = get_luma(texture(PrePass0, vTexCoord - 2.0*dx).rgb);
      float b = get_luma(texture(PrePass0, vTexCoord -     dx).rgb);
      float c = get_luma(texture(PrePass0, vTexCoord + 2.0*dx).rgb);
      float d = get_luma(texture(PrePass0, vTexCoord +     dx).rgb);
      float e = get_luma(texture(PrePass0, vTexCoord         ).rgb);	  
      signal.x = mix(signal.x, clamp(signal.x, pow(min(min(min(a,b),min(c,d)),e), params.ntsc_gamma), pow(max(max(max(a,b),max(c,d)),e), params.ntsc_gamma)), params.ntsc_ring);
   }
   
   float orig = get_luma(texture(PrePass0, TexD * vec2(speedup, 1.0)).rgb);
   orig = pow(orig, params.ntsc_gamma);   
   FragColor = vec4(signal, orig);
}  
