#version 450 core

#extension GL_EXT_multiview : enable
#extension GL_ARB_separate_shader_objects : enable
#extension GL_ARB_shading_language_420pack : enable

layout(location = 0) in vec2 inTexCoord;

layout(location = 0) out vec4 outFragColor;

layout(set = 0, binding = 0) uniform sampler2DArray uTexture;

void main(){
  vec2 fragCoordInvScale = vec2(1.0) / vec2(textureSize(uTexture, 0).xy);
  vec4 p = vec4(inTexCoord, vec2(inTexCoord - (fragCoordInvScale * (0.5 + (1.0 / 4.0)))));
  const float FXAA_SPAN_MAX = 8.0,
              FXAA_REDUCE_MUL = 1.0 / 8.0,
              FXAA_REDUCE_MIN = 1.0 / 128.0;
  vec3 rgbNW = textureLod(uTexture, vec3(p.zw, float(gl_ViewIndex)), 0.0).xyz,
       rgbNE = textureLodOffset(uTexture, vec3(p.zw, float(gl_ViewIndex)), 0.0, ivec2(1, 0)).xyz,
       rgbSW = textureLodOffset(uTexture, vec3(p.zw, float(gl_ViewIndex)), 0.0, ivec2(0, 1)).xyz,
       rgbSE = textureLodOffset(uTexture, vec3(p.zw, float(gl_ViewIndex)), 0.0, ivec2(1, 1)).xyz,
       rgbM = textureLod(uTexture, vec3(p.xy, float(gl_ViewIndex)), 0.0).xyz,
       luma = vec3(0.299, 0.587, 0.114);
  float lumaNW = dot(rgbNW, luma),
        lumaNE = dot(rgbNE, luma),
        lumaSW = dot(rgbSW, luma),
        lumaSE = dot(rgbSE, luma),
        lumaM = dot(rgbM, luma),
        lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE))), 
        lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));
  vec2 dir = vec2(-((lumaNW + lumaNE) - (lumaSW + lumaSE)), ((lumaNW + lumaSW) - (lumaNE + lumaSE)));
  float dirReduce = max((lumaNW + lumaNE + lumaSW + lumaSE) * (0.25 * FXAA_REDUCE_MUL), FXAA_REDUCE_MIN), 
  rcpDirMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + dirReduce);
  dir = min(vec2(FXAA_SPAN_MAX, FXAA_SPAN_MAX), max(vec2(-FXAA_SPAN_MAX, -FXAA_SPAN_MAX), dir * rcpDirMin)) * fragCoordInvScale;
  vec4 rgbA = (1.0 / 2.0) * (textureLod(uTexture, vec3(p.xy + (dir * ((1.0 / 3.0) - 0.5)), float(gl_ViewIndex)), 0.0).xyzw + textureLod(uTexture, vec3(p.xy + (dir * ((2.0 / 3.0) - 0.5)), float(gl_ViewIndex)), 0.0).xyzw),
       rgbB = (rgbA * (1.0 / 2.0)) + ((1.0 / 4.0) * (textureLod(uTexture, vec3(p.xy + (dir * ((0.0 / 3.0) - 0.5)), float(gl_ViewIndex)), 0.0).xyzw + textureLod(uTexture, vec3(p.xy + (dir * ((3.0 / 3.0) - 0.5)), float(gl_ViewIndex)), 0.0).xyzw));
  float lumaB = dot(rgbB.xyz, luma);
  vec4 outColor = ((lumaB < lumaMin) || (lumaB > lumaMax)) ? rgbA : rgbB;
  outFragColor = vec4(mix(pow((outColor.xyz + vec3(5.5e-2)) / vec3(1.055), vec3(2.4)), outColor.xyz / vec3(12.92), lessThan(outColor.xyz, vec3(4.045e-2))), outColor.w);
}
