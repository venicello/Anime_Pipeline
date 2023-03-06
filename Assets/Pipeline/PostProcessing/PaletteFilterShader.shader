Shader "Hidden/PaletteFilterShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _PaletteTex("Palette", 2D) = "black" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            sampler2D _MainTex;
            sampler2D _PaletteTex;
            sampler2D _CameraGBufferTexture2;

            fixed4 frag (v2f i) : SV_Target
            {
                float4 colIn = tex2D(_MainTex, i.uv);
                float3 col = float3(saturate(colIn.r), saturate(colIn.g), saturate(colIn.b));
                //col.gb = 1 - col.gb;
                float tickDown = 0.99;

                float rP = (col.r * tickDown) * 16.0;

                float yOffset = floor(rP);
                float xOffset = floor((rP - yOffset) * 16.0) / 16.0;

                yOffset /= 16.0;

                float u = (col.g * tickDown) / 16.0;
                u += xOffset;

                float v = (col.b * tickDown) / 16.0;
                v += yOffset;

                float4 outC = tex2D(_PaletteTex, float2(u, v));

                fixed4 mask = tex2D(_CameraGBufferTexture2, i.uv);

                return lerp(colIn, outC, mask.a);
            }
            ENDCG
        }
    }
}
