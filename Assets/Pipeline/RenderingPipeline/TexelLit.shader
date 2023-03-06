Shader "Unlit/TexelLit"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vertAdd
            #pragma fragment fragAddTexel
            #include "UnityStandardCoreForward.cginc"

            uniform float4 _MainTex_TexelSize;

            half4 fragAddTexel(VertexOutputForwardAdd i) : SV_Target
            {
                // 1.) Calculate how much the texture UV coords need to
                //     shift to be at the center of the nearest texel.
                float2 originalUV = i.tex.xy;
                float2 centerUV = floor(originalUV * (_MainTex_TexelSize.zw)) / _MainTex_TexelSize.zw + (_MainTex_TexelSize.xy / 2.0);
                float2 dUV = (centerUV - originalUV);

                // 2a.) Get this fragment's world position
                float3 originalWorldPos = IN_WORLDPOS_FWDADD(i);

                // 2b.) Calculate how much the texture coords vary over fragment space.
                //      This essentially defines a 2x2 matrix that gets
                //      texture space (UV) deltas from fragment space (ST) deltas
                // Note: I call fragment space (S,T) to disambiguate.
                float2 dUVdS = ddx(originalUV);
                float2 dUVdT = ddy(originalUV);

                // 2c.) Invert the fragment from texture matrix
                float2x2 dSTdUV = float2x2(dUVdT[1], -dUVdT[0], -dUVdS[1], dUVdS[0]) * (1.0f / (dUVdS[0] * dUVdT[1] - dUVdT[0] * dUVdS[1]));


                // 2d.) Convert the UV delta to a fragment space delta
                float2 dST = mul(dSTdUV , dUV);

                // 2e.) Calculate how much the world coords vary over fragment space.
                float3 dXYZdS = ddx(originalWorldPos);
                float3 dXYZdT = ddy(originalWorldPos);

                // 2f.) Finally, convert our fragment space delta to a world space delta
                // And be sure to clamp it to SOMETHING in case the derivative calc went insane
                // Here I clamp it to -1 to 1 unit in unity, which should be orders of magnitude greater
                // than the size of any texel.
                float3 dXYZ = dXYZdS * dST[0] + dXYZdT * dST[1];

                dXYZ = clamp(dXYZ, -1, 1);

                // 3.) Transform the snapped UV back to world space
                float3 snappedWorldPos = originalWorldPos + dXYZ;

                UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);

                // 4.) Insert the snapped position and corrected eye vec into the input structure
                i.posWorld = snappedWorldPos;
                i.eyeVec = half4(NormalizePerVertexNormal(snappedWorldPos.xyz - _WorldSpaceCameraPos.xyz), i.eyeVec.w);

                // Calculate lightDir using the snapped psotion at texel center
                float3 lightDir = _WorldSpaceLightPos0.xyz - snappedWorldPos.xyz * _WorldSpaceLightPos0.w;
                #ifndef USING_DIRECTIONAL_LIGHT
                    lightDir = NormalizePerVertexNormal(lightDir);
                #endif
                i.tangentToWorldAndLightDir[0].w = lightDir.x;
                i.tangentToWorldAndLightDir[1].w = lightDir.y;
                i.tangentToWorldAndLightDir[2].w = lightDir.z;

                //FRAGMENT_SETUP_FWDADD(s)
                FragmentCommonData s = FragmentSetup(i.tex, i.eyeVec, IN_VIEWDIR4PARALLAX_FWDADD(i), i.tangentToWorldAndLightDir, snappedWorldPos);

                UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld)
                UnityLight light = AdditiveLight(IN_LIGHTDIR_FWDADD(i), atten);
                UnityIndirect noIndirect = ZeroIndirect();

                // 4.) Call Unity's standard light calculation!
                half4 c = UNITY_BRDF_PBS(s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, light, noIndirect);

                UNITY_APPLY_FOG_COLOR(i.fogCoord, c.rgb, half4(0,0,0,0)); // fog towards black in additive pass
                return OutputForward(c, s.alpha);
            }
            ENDCG
        }
    }
}
