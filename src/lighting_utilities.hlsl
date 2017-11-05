#ifndef LIGHTING_UTILS_INCLUDED
#define LIGHTING_UTILS_INCLUDED

#include "constants_list.hlsl"

struct Lighting
{
   float4 diffuse;
   float4 static_diffuse;
};

namespace light
{

float3 ambient(float3 world_normal)
{
   float4 factor = world_normal.y * -constant_0.yyyy + constant_0.yyyy;

   float3 color;

   color.rgb = light_ambient_color_top.rgb * -factor.rgb + light_ambient_color_top.rgb;
   color.rgb = light_ambient_color_bottom.rgb * factor.rgb + light_ambient_color_bottom.rgb;

   return color;
}

namespace diffuse
{

float intensity_directional(float3 world_normal, float4 direction)
{
   float intensity = dot(world_normal.xyz, -direction.xyz);

   return max(intensity, constant_0.x);
}

float intensity_point(float3 world_normal, float4 world_position, float4 light_position)
{
   float3 light_dir = world_position.xyz + -light_position.xyz;

   const float dir_dot = dot(light_dir, light_dir);

   light_dir *= rsqrt(dir_dot);

   float3 intensity;

   const float inv_range_sq = light_position.w;

   intensity.x = constant_0.z;
   intensity.z = -dir_dot * inv_range_sq + intensity.x;
   intensity.y = dot(world_normal.xyz, -light_dir);
   intensity = max(intensity, constant_0.xxx);

   return intensity.y * intensity.z;
}

float intensity_spot(float3 world_normal, float4 world_position)
{
   const float inv_range_sq = light_spot_pos.w;
   const float bidirectional = light_spot_dir.w;

   // find light direction
   float3 light_dir = world_position.xyz + -light_spot_pos.xyz;

   const float dir_dot = dot(light_dir, light_dir);
   const float dir_rsqr = rsqrt(dir_dot);

   light_dir *= dir_rsqr;

   // calculate angular attenuation
   float4 attenuation;

   attenuation = dot(light_dir, light_spot_dir.xyz);
   attenuation.x = (dir_rsqr < constant_0.x) ? 1.0f : 0.0f;
   attenuation.y = constant_0.z;
   attenuation.x = bidirectional * -attenuation.x + attenuation.y;
   attenuation.w = attenuation.w * attenuation.x;

   // compute distance attenuation
   attenuation.z = -dir_dot * inv_range_sq + attenuation.y;
   attenuation = max(attenuation, constant_0.xxxx);

   // set if inside the inner/outer cone
   attenuation.y = (attenuation.w >= light_spot_params.x) ? 1.0f : 0.0f;
   attenuation.x = (attenuation.w < constant_0.x) ? 1.0f : 0.0f;
   attenuation.z *= attenuation.y;

   // compute the falloff if inbetween the inner and outer cone
   attenuation.y = attenuation.w + -light_spot_params.x;
   attenuation.y *= light_spot_params.z;
   attenuation.w *= light_spot_params.w * attenuation.x;
   attenuation.x = dot(world_normal, -light_dir);

   float4 coefficient = lit(attenuation.x, attenuation.y, attenuation.w);

   // calculate spot attenuated intensity
   attenuation = max(attenuation, constant_0.xxxx);

   return (attenuation.z * coefficient.z) * attenuation.x;
}

Lighting calculate(float3 world_normal, float4 world_position, 
                   float4 static_diffuse_lighting)
{
   Lighting lighting;

#ifdef LIGHTING_DIRECTIONAL
   lighting.diffuse.a = constant_0.x;

   lighting.diffuse.rgb = ambient(world_normal) + static_diffuse_lighting.rgb;

   float4 intensity = constant_0.xxxz;

   intensity.x = intensity_directional(world_normal, light_directional_0_dir);
   lighting.diffuse += intensity.x * light_directional_0_color;

   intensity.w = intensity_directional(world_normal, light_directional_1_dir);
   lighting.diffuse += intensity.w * light_directional_1_color;

#ifdef LIGHTING_POINT_0
   intensity.y = intensity_point(world_normal, world_position, light_point_0_pos);
   lighting.diffuse += intensity.y * light_point_0_color;
#endif

#ifdef LIGHTING_POINT_1
   intensity.w = intensity_point(world_normal, world_position, light_point_1_pos);
   lighting.diffuse += intensity.w * light_point_1_color;
#endif

#ifdef LIGHTING_POINT_23
   intensity.w = intensity_point(world_normal, world_position, light_point_2_pos);
   lighting.diffuse += intensity.w * light_point_2_color;

   intensity.w = intensity_point(world_normal, world_position, light_point_3_pos);
   lighting.diffuse += intensity.w * light_point_3_color;
#elif defined(LIGHTING_SPOT_0)
   intensity.z = intensity_spot(world_normal, world_position);
   lighting.diffuse += intensity.z * light_point_2_color;
#endif

   lighting.static_diffuse = static_diffuse_lighting;
   lighting.static_diffuse.w = dot(light_proj_selector, intensity);
   lighting.diffuse.rgb += -light_proj_color.rgb * lighting.static_diffuse.w;

   float scale = max(lighting.diffuse.r, lighting.diffuse.g);
   scale = max(scale, lighting.diffuse.z);
   scale = max(scale, constant_0.z);
   scale = rcp(scale);
   lighting.static_diffuse.rgb * scale;
   lighting.static_diffuse.rgb * hdr_info.zzz;
#else // LIGHTING_DIRECTIONAL

   lighting.diffuse = hdr_info.zzzw;
   lighting.static_diffuse = constant_0.xxxx;
#endif

   return lighting;
}

}
}

#endif