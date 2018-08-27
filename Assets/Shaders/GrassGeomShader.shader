Shader "Custom/GrassGeomShader" {
   Properties{
      _MainTex("Albedo (RGB)", 2D) = "white" {}
   _Cutoff("Cutoff", Range(0,1)) = 0.25
      _GrassHeight("Grass Height", Float) = 0.25
      _WindSpeed("Wind Speed", Float) = 100
      _WindStrength("Wind Strength", Float) = 0.5
   }
      SubShader{
      Tags{
      "Queue" = "Geometry"
      "RenderType" = "Opaque"
   }
      LOD 200
      Pass
   {
      Name "ForwardBase"
      Tags{ "LightMode" = "ForwardBase" }
      CULL OFF

      CGPROGRAM
#include "UnityCG.cginc"
#pragma vertex vert
#pragma fragment frag
#pragma geometry geom
#include "Lighting.cginc"
#pragma multi_compile_fwdbase
#include "AutoLight.cginc"

#pragma target 5.0

      sampler2D _MainTex;

   struct v2g
   {
      float4 pos : SV_POSITION;
      float3 norm : NORMAL;
      float2 uv : TEXCOORD0;
      float3 color : TEXCOORD1;
   };

   struct g2f
   {
      float4 pos : SV_POSITION;
      float3 norm : NORMAL;
      float2 uv : TEXCOORD0;
      LIGHTING_COORDS(1,2)
   };

   struct QuadComponents {
      float3 v0;
      float3 v1;
      float3 norm;
      float3 color;
   };

   half _GrassHeight;
   half _Cutoff;
   half _WindStrength;
   half _WindSpeed;

   void BuildQuad(QuadComponents quadComp, float3 displacement, inout TriangleStream<g2f> triStream) {
      g2f OUT;
      OUT.norm = cross(quadComp.norm, quadComp.v0);

      float3 position[4];
      float2 uv[4];
      int vertexIndices[4] = { 0,1,2,3 };
      position[0] = quadComp.v0 - displacement * 0.5 * _GrassHeight;
      uv[0] = float2(0, 0);
      position[1] = quadComp.v1 - displacement * 0.5 * _GrassHeight; uv[1] = float2(0, 1);
      position[2] = quadComp.v0 + displacement * 0.5 * _GrassHeight; uv[2] = float2(1, 0);
      position[3] = quadComp.v1 + displacement * 0.5 * _GrassHeight; uv[3] = float2(1, 1);

      for (int i = 0; i < 4; i++) {
         OUT.uv = uv[vertexIndices[i]];
         OUT.pos = UnityObjectToClipPos(position[vertexIndices[i]]);
         TRANSFER_VERTEX_TO_FRAGMENT(OUT);
         triStream.Append(OUT);
      }

      triStream.RestartStrip();
   }

   v2g vert(appdata_full v)
   {
      v2g OUT;
      OUT.pos = v.vertex;
      OUT.norm = v.normal;
      OUT.uv = v.texcoord;
      OUT.color = tex2Dlod(_MainTex, v.texcoord).rgb;
      return OUT;
   }

   [maxvertexcount(12)]
   void geom(point v2g IN[1], inout TriangleStream<g2f> triStream)
   {
      QuadComponents quadComp;
      quadComp.v0 = IN[0].pos.xyz;
      quadComp.v1 = IN[0].pos.xyz + IN[0].norm * _GrassHeight;

      float3 perpendicularAngle = float3(0, 0, 1);
      quadComp.norm = cross(perpendicularAngle, IN[0].norm);
      quadComp.color = (IN[0].color);

      float3 wind = float3(sin(_Time.x  * _WindSpeed + quadComp.v0.x * _WindSpeed) + sin(_Time.x * _WindSpeed + quadComp.v0.z * 2), 0, cos(_Time.x  * _WindSpeed + quadComp.v0.z) + cos(_Time.x  * _WindSpeed + quadComp.v0.x * 2));
      quadComp.v1 += wind * _WindStrength;

      float sin60 = 0.866f;
      float cos60 = 0.5f;

      //Creates inner section grass mesh - Can be replaced
      BuildQuad(quadComp, perpendicularAngle, triStream);
      BuildQuad(quadComp, float3(sin60, 0, cos60), triStream);
      BuildQuad(quadComp, float3(sin60, 0, -cos60), triStream);
   }

   half4 frag(g2f IN) : COLOR
   {
      /*
      g2f contains {pos, norm, uv, LIGHTING_COORDS}
      */
      fixed4 c = tex2D(_MainTex, IN.uv);
   clip(c.a - _Cutoff);

   half3 worldNormal = UnityObjectToWorldNormal(IN.norm);
   half nl = max(0, dot(worldNormal, _WorldSpaceLightPos0.xyz));
   fixed3 diff = nl * _LightColor0.rgb;
   fixed3 ambient = ShadeSH9(half4(worldNormal, 1));
   fixed attenuation = LIGHT_ATTENUATION(IN);

   fixed3 lighting = diff * attenuation + ambient * 2;
   c.rgb *= lighting;
   return c;
   }
      ENDCG
   }
   }
   FallBack "Diffuse"
}
