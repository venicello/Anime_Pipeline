#include "UnityCG.cginc"
#include "UnityStandardConfig.cginc"
#include "UnityLightingCommon.cginc"

#include "UnityShaderVariables.cginc"
#include "UnityToonGBuffer.cginc"
#include "UnityGlobalIllumination.cginc"

#define BRDF_PBS_TEST BRDF3_Unity_PBS

struct SurfaceOutputStandard
{
    fixed3 Albedo;      // base (diffuse or specular) color
    float3 Normal;      // tangent space normal, if written
    half3 Emission;
    half Metallic;      // 0=non-metal, 1=metal
    // Smoothness is the user facing name, it should be perceptual smoothness but user should not have to deal with it.
    // Everywhere in the code you meet smoothness it is perceptual smoothness
    half Smoothness;    // 0=rough, 1=smooth
    half Occlusion;     // occlusion (default 1)
    fixed Alpha;        // alpha for transparencies
};

inline half4 LightingStandard_Deferred(SurfaceOutputStandard s, float3 viewDir, UnityGI gi, out half4 outGBuffer0, out half4 outGBuffer1, out half4 outGBuffer2)
{
    half oneMinusReflectivity;
    half3 specColor;
    s.Albedo = DiffuseAndSpecularFromMetallic(s.Albedo, s.Metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);

    half4 c = BRDF_PBS_TEST(s.Albedo, specColor, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, gi.light, gi.indirect);

    half4 light = BRDF_PBS_TEST(half4(1, 1, 1, 1), specColor, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, gi.light, gi.indirect);
    
    float lightValue = (0.2126 * light.r) + (0.7152 * light.g) + (0.0722 * light.b);
    
    UnityStandardToonData data;
    data.diffuseColor = s.Albedo;
    data.occlusion = s.Occlusion;
    data.metal = s.Metallic;
    data.smoothness = s.Smoothness;
    data.normalWorld = s.Normal;

    UnityStandardToonDataToGbuffer(data, outGBuffer0, outGBuffer1, outGBuffer2);

    half4 emission = half4(s.Emission + c.rgb, lightValue);
    return emission;
}

half smoothPosterize(float inVal, float bands)
{
    half roundVal = floor(inVal * bands);
    half remainder = (inVal * bands) - roundVal;
    return (roundVal + smoothstep(0.0, 0.04, remainder)) / bands;
}

inline half luminance(half3 lightVal)
{
    return (0.2126 * lightVal.r) + (0.7152 * lightVal.g) + (0.0722 * lightVal.b);
}

// Based on Minimalist CookTorrance BRDF
// Implementation is slightly different from original derivation: http://www.thetenthplanet.de/archives/255
//
// * NDF (depending on UNITY_BRDF_GGX):
//  a) BlinnPhong
//  b) [Modified] GGX
// * Modified Kelemen and Szirmay-?Kalos for Visibility term
// * Fresnel approximated with 1/LdotH
half4 BRDF_Unity_Toon(half3 diffColor, half3 specColor, half specStep, half oneMinusReflectivity, half smoothness,
    float3 normal, float3 viewDir,
    UnityLight light, UnityIndirect gi)
{
    float3 halfDir = Unity_SafeNormalize(float3(light.dir) + viewDir);

    half nl = smoothstep(0.0, 0.04, saturate(dot(normal, light.dir)));
    
    float nh = saturate(dot(normal, halfDir));
    half nv = saturate(dot(normal, viewDir));
    float lh = saturate(dot(light.dir, halfDir));

    // Specular term
    half perceptualRoughness = SmoothnessToPerceptualRoughness(smoothness);
    half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

#if UNITY_BRDF_GGX

    // GGX Distribution multiplied by combined approximation of Visibility and Fresnel
    // See "Optimizing PBR for Mobile" from Siggraph 2015 moving mobile graphics course
    // https://community.arm.com/events/1155
    half a = roughness;
    float a2 = a * a;

    float d = nh * nh * (a2 - 1.f) + 1.00001f;
#ifdef UNITY_COLORSPACE_GAMMA
    // Tighter approximation for Gamma only rendering mode!
    // DVF = sqrt(DVF);
    // DVF = (a * sqrt(.25)) / (max(sqrt(0.1), lh)*sqrt(roughness + .5) * d);
    float specularTerm = a / (max(0.32f, lh) * (1.5f + roughness) * d);
#else
    float specularTerm = a2 / (max(0.1f, lh * lh) * (roughness + 0.5f) * (d * d) * 4);
#endif

    // on mobiles (where half actually means something) denominator have risk of overflow
    // clamp below was added specifically to "fix" that, but dx compiler (we convert bytecode to metal/gles)
    // sees that specularTerm have only non-negative terms, so it skips max(0,..) in clamp (leaving only min(100,...))
#if defined (SHADER_API_MOBILE)
    specularTerm = specularTerm - 1e-4f;
#endif

#else

    // Legacy
    half specularPower = PerceptualRoughnessToSpecPower(perceptualRoughness);
    // Modified with approximate Visibility function that takes roughness into account
    // Original ((n+1)*N.H^n) / (8*Pi * L.H^3) didn't take into account roughness
    // and produced extremely bright specular at grazing angles

    half invV = lh * lh * smoothness + perceptualRoughness * perceptualRoughness; // approx ModifiedKelemenVisibilityTerm(lh, perceptualRoughness);
    half invF = lh;

    half specularTerm = ((specularPower + 1) * pow(nh, specularPower)) / (8 * invV * invF + 1e-4h);

#ifdef UNITY_COLORSPACE_GAMMA
    specularTerm = sqrt(max(1e-4f, specularTerm));
#endif

#endif

#if defined (SHADER_API_MOBILE)
    specularTerm = clamp(specularTerm, 0.0, 100.0); // Prevent FP16 overflow on mobiles
#endif
#if defined(_SPECULARHIGHLIGHTS_OFF)
    specularTerm = 0.0;
#endif
    specularTerm = step(specStep, specularTerm);
    // surfaceReduction = Int D(NdotH) * NdotH * Id(NdotL>0) dH = 1/(realRoughness^2+1)

    // 1-0.28*x^3 as approximation for (1/(x^4+1))^(1/2.2) on the domain [0;1]
    // 1-x^3*(0.6-0.08*x)   approximation for 1/(x^4+1)
#ifdef UNITY_COLORSPACE_GAMMA
    half surfaceReduction = 0.28;
#else
    half surfaceReduction = (0.6 - 0.08 * perceptualRoughness);
#endif

    surfaceReduction = 1.0 - roughness * perceptualRoughness * surfaceReduction;

    half grazingTerm = saturate(smoothness + (1 - oneMinusReflectivity));
    
    float bands = 8.0;
    half lightValue = smoothPosterize(luminance(light.color.rgb), bands);
    //floor plus modulus cubed.  fix this to do vectors instead of individual floats
    half lengthRaw = clamp(length(light.color), 0.001, 1);
    half lengthZero = ceil(saturate(length(light.color)));
    half3 lightNorm = (light.color / lengthRaw) * lengthZero;
    half3 posterizedColor = lightNorm * lightValue;
    posterizedColor = lerp(posterizedColor, light.color, 0.25);
    half3 color = (diffColor + specularTerm * specColor) * posterizedColor * nl
        + gi.diffuse * diffColor
        + surfaceReduction * gi.specular * FresnelLerpFast(specColor, grazingTerm, nv);
    
    return half4(color, 1.0);
}