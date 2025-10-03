#version 450

// NTSC-Adaptive Pass3
// based on Themaister's NTSC shader


layout(push_constant) uniform Push
{
   vec4 OutputSize;
   vec4 OriginalSize;
   vec4 SourceSize;
   uint FrameCount;
   float ntsc_phase;
   float auto_res;
   float ntsc_sharp;
   float ntsc_charp;
   float ntsc_charp3;
   float ntsc_shape;
   float ntsc_gamma;
   float ntsc_rainbow1;
   float speedup;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma parameter auto_res "          SNES/Amiga Hi-Res Auto Mode" 0.0 0.0 1.0 1.0
#pragma parameter speedup  "          Speedup w. higher Internal Res." 1.0 1.0 4.0 1.0
float auto_rez = mix(1.0, 0.5, clamp(params.auto_res * round(params.OriginalSize.x/300.0)-1.0, 0.0, 1.0));
#define speedup params.speedup

#pragma parameter ntsc_phase   "NTSC Phase: Auto | 2 phase | 3 phase | Mixed" 1.0 1.0 5.0 1.0
#pragma parameter ntsc_rainbow1 "NTSC Coloring/Rainbow Effect (2-phase)"  0.0 0.0 3.0 1.0

#pragma parameter ntsc_sharp  "NTSC Sharpness (Adaptive)" 0.0 -10.0 10.0 0.50
#pragma parameter ntsc_shape  "NTSC Sharpness Shape" 0.80 0.5 1.0 0.025
#pragma parameter ntsc_charp  "NTSC Preserve 'Edge' Colors 2-phase" 0.0 0.0 10.0 0.50
#pragma parameter ntsc_charp3 "NTSC Preserve 'Edge' Colors 3-phase" 0.0 0.0 10.0 0.50
#pragma parameter ntsc_gamma  "NTSC Filtering Gamma Correction" 1.0 0.25 2.5 0.025
#pragma parameter ntsc-row5 "------------------------------------------------" 0.0 0.0 0.0 1.0

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 vTexCoord0;
layout(location = 2) out vec2 vTexCoord1;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord0 = TexCoord / vec2(speedup, 1.0);
   vTexCoord1 = (floor(vTexCoord0*params.OriginalSize.xy)+0.5)*params.OriginalSize.zw;   
   vTexCoord  = (TexCoord + vec2(0.5 * (params.OriginalSize.z/auto_rez)/4.0, 0.0)); // Compensate for decimate-by-2.
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 vTexCoord0;
layout(location = 2) in vec2 vTexCoord1;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D NPass1;
layout(set = 0, binding = 4) uniform sampler2D PrePass0;

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

float smothstep (float e0, float e1, float x)
{
   return clamp((x - e0) / (e1 - e0), 0.0, 1.0);
}

void main()
{

if (speedup > 1.25 && ((params.OriginalSize.y > 500.0 && params.SourceSize.y > 820.0) || params.SourceSize.y > 820.0))
{
   vec3 signal = texture(Source, vTexCoord0).xyz;
   signal.x = pow(signal.x, 1.0/params.ntsc_gamma);   
   FragColor = vec4(clamp(yiq2rgb(signal), 0.0, 1.0), 1.0);
}
else
{

   vec2 xx = vec2(0.5000 * params.OriginalSize.z/auto_rez/speedup, 0.0);
   vec2 dx = vec2(0.0625 * params.OriginalSize.z/auto_rez/speedup, 0.0);
   
   vec2 texcoord0 = (floor(params.OriginalSize.xy * vTexCoord) + 0.5)*params.OriginalSize.zw;
   vec2 texcoord  = vTexCoord - 2.0*dx;
   vec2 vTex = vTexCoord;
   
   if (speedup > 1.25) { texcoord0 = vTexCoord1; texcoord = vTexCoord0; vTex = vTexCoord0; }
   
   vec3 l1  = texture(Source, texcoord + xx).xyz;
   vec3 l2  = texture(Source, texcoord - xx).xyz;

   float dy = 0.0;

   xx = vec2(params.OriginalSize.z/auto_rez/speedup, 0.0);

   float phase = (params.ntsc_phase < 1.5) ? ((params.OriginalSize.x * auto_rez > 300.0) ? 2.0 : 3.0) : ((params.ntsc_phase > 2.5) ? 3.0 : 2.0);
   if (params.ntsc_phase > 3.5) phase = 3.0;

   float ca = texture(NPass1, texcoord0 - xx - xx).a;
   float c0 = texture(NPass1, texcoord0 - xx).a;
   float c1 = texture(NPass1, texcoord0     ).a;
   float c2 = texture(NPass1, texcoord0 + xx).a;
   float cb = texture(NPass1, texcoord0 + xx + xx).a;

   float th = (phase < 2.5) ? 0.025 : 0.0075;
   float line0  = smothstep(th, 0.0, min(abs(c1-c0),abs(c2-c1)));
   float line1  = max(smothstep(th, 0.0, min(abs(ca-c0),abs(c2-cb))), line0);
   float line2  = max(smothstep(th, 0.0, min(abs(ca-c2),abs(c0-cb))), line1);

   vec3 ref = texture(Source, texcoord).xyz;
   vec2 orig = ref.yz;
   
   if (params.ntsc_rainbow1 > 0.5 && phase < 2.5)
   {
      float ybool = 1.0;
      if ((params.ntsc_rainbow1 < 1.5) && bool(line0)) ybool = 0.0; else
      if ((params.ntsc_rainbow1 < 2.5) && bool(line2)) ybool = 0.0; 
      float line_no  = floor(mod(params.OriginalSize.y*vTexCoord.y, 2.0));
      float frame_no = floor(mod(float(params.FrameCount),2.0));
      float ii = abs(line_no-frame_no);
      dy = ii * params.OriginalSize.w*ybool;
      vec2 ref1 = texture(Source, texcoord - vec2(0.0, dy)).yz;
      vec2 ref2 = texture(Source, texcoord + vec2(0.0, dy)).yz;
      vec2 rdf1 = abs(orig-ref1); vec2 rdf2 = abs(orig-ref2);
      rdf1 = rdf1/max(rdf1+rdf2,0.0000001);
      ref.yz = mix(ref1,ref2,rdf1);
   }
   
   float lum1 = min(texture(NPass1, vTex - dx).a, texture(NPass1, vTex + dx).a);
   float lum2 = ref.x;
   vec3 l3 = abs(l1-l2);
   
   float dif = max(max(l3.x, l3.y), max(l3.z, abs(l1.x*l1.x-l2.x*l2.x)));
   float dff = pow(dif, 0.125);
   
   float lc = smothstep(0.20, 0.10, abs(lum2-lum1))*dff;

   float tmp = smothstep(0.05-0.03*lc, 0.425 - 0.375*lc, dif);
   float tmp1 = pow((tmp+0.1)/1.1, 0.25);
   float sweight = mix(tmp, tmp1, line0);
   float sweighr = mix(tmp, tmp1, line2);
   
   vec3 signal = ref;

   float ntsc_sharp = abs(params.ntsc_sharp);
   
   if (ntsc_sharp > 0.25)
   {
      float mixer = sweight;
      if (params.ntsc_sharp > 0.25) mixer = sweighr; mixer*=0.1*ntsc_sharp;
      float lummix = mix(lum2, lum1, mixer);
      float lm1 =  mix(lum2*lum2, lum1*lum1,mixer); lm1 = sqrt(lm1);
      float lm2 =  mix(sqrt(lum2), sqrt(lum1),mixer); lm2 = lm2*lm2;
  
      float k1 = abs(lummix - lm1) + 0.00001;
      float k2 = abs(lummix - lm2) + 0.00001;
	  
      signal.x = min((k2*lm1 + k1*lm2)/(k1+k2), 1.0);
      signal.x = min(signal.x, max(params.ntsc_shape*signal.x, lum2));
   }   

   if ((params.ntsc_charp + params.ntsc_charp3) > 0.25)
   {
      dx.x = 0.0625 * params.OriginalSize.z/auto_rez;
      float texcoordx = params.OriginalSize.x * (vTexCoord.x+dx.x) - 0.5;   
      float fpx = fract(texcoordx);
      texcoordx = (floor(texcoordx ) + 0.5) * params.OriginalSize.z;
      float mixer = sweight;
      if (params.ntsc_sharp > 0.25) mixer = sweighr;
      mixer = mix(smothstep(0.075,0.125,max(l3.y,l3.z)), smothstep(0.015,0.0275,dif), line2)*mixer; 
      mixer*=0.1*((phase < 2.5) ? params.ntsc_charp : params.ntsc_charp3);
      texcoord = vec2(texcoordx,texcoord.y);
      vec3 orig_ch = rgb2yiq(mix(texture(PrePass0, texcoord).rgb , texture(PrePass0, texcoord+16.0*dx).rgb, clamp(1.5*fpx-0.25,0.0,1.0)));
      signal.yz = mix(signal.yz, orig_ch.yz, mixer);
   }
   
   signal.x = pow(signal.x, 1.0/params.ntsc_gamma);
   signal = clamp(yiq2rgb(signal), 0.0, 1.0);
   sweighr = (phase == 2.0 || params.ntsc_phase > 3.5) ? sweighr : 1.0;
   
   FragColor = vec4(signal, sweighr);
}
}  
