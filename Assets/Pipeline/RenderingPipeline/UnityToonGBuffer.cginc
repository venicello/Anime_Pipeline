// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_GBUFFER_INCLUDED
#define UNITY_GBUFFER_INCLUDED

//-----------------------------------------------------------------------------
// Main structure that store the data from the standard shader (i.e user input)
struct UnityStandardToonData
{
    half3   diffuseColor, specColor;
    half    occlusion;

    half    metal;
    half    smoothness;

    float3  normalWorld;        // normal in world space
    half    crosshatch;
    half    lineWork;
    half    lineAtten;
    half mask;
};

//-----------------------------------------------------------------------------
// This will encode UnityStandardData into GBuffer
void UnityStandardToonDataToGbuffer(UnityStandardToonData data, out half4 outGBuffer0, out half4 outGBuffer1, out half4 outGBuffer2)
{
    // RT0: diffuse color (rgb), occlusion (a) - sRGB rendertarget
    outGBuffer0 = half4(data.diffuseColor, data.occlusion);

    // RT1: UNUSED!!!
    outGBuffer1 = half4(0, 0, data.lineWork, data.lineAtten);

    // RT2: normal (rgb), fg / bg mask? a
    outGBuffer2 = half4(data.normalWorld * 0.5f + 0.5f, data.mask);

}
//-----------------------------------------------------------------------------
// This decode the Gbuffer in a UnityStandardData struct
UnityStandardToonData UnityStandardToonDataFromGbuffer(half4 inGBuffer0, half4 inGBuffer1, half4 inGBuffer2)
{
    UnityStandardToonData data;

    data.diffuseColor = inGBuffer0.rgb;
    data.occlusion      = inGBuffer0.a;

    data.metal = 0; // inGBuffer1.g;
    data.smoothness = 0;// inGBuffer1.a;
    
    data.specColor = 0; // lerp(unity_ColorSpaceDielectricSpec.rgb, inGBuffer0.rgb, inGBuffer1.g);

    data.normalWorld    = normalize((float3)inGBuffer2.rgb * 2 - 1);
    data.crosshatch = inGBuffer0.a;
    data.lineWork = inGBuffer1.b;
    data.lineAtten = inGBuffer1.a;

    return data;
}
//-----------------------------------------------------------------------------
// In some cases like for terrain, the user want to apply a specific weight to the attribute
// The function below is use for this
void UnityStandardToonDataApplyWeightToGbuffer(inout half4 inOutGBuffer0, inout half4 inOutGBuffer1, inout half4 inOutGBuffer2, half alpha)
{
    // With UnityStandardData current encoding, We can apply the weigth directly on the gbuffer
    inOutGBuffer0.rgb   *= alpha; // diffuseColor
    inOutGBuffer1       *= alpha; // SpecularColor and Smoothness
    inOutGBuffer2.rgb   *= alpha; // Normal
}
//-----------------------------------------------------------------------------

#endif // #ifndef UNITY_GBUFFER_INCLUDED
