Shader "MW/Player" {
    Properties {
        _MainTex ("MainTex", 2D) = "white" {}
		_MixPower ("_Mix Power", Range(0,.9)) = 0
		_MixColor ("_Mix Color", Color) = (0,0,0,1)

		_RimColor ("Rim Color", Color) = (0,0.545,1,1)
		_RimStrength ("Rim Strength", float) = 0

		_GrayPower("Gray Power", float) = 0.3
    }
    SubShader {
		//普通显示
		Pass{
			Tags 
			{
				"Queue" = "Geometry+11"
			}
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog

			#include "UnityCG.cginc"

			struct v2f{
				fixed4 sv_pos: SV_POSITION;
				fixed4 uv: TEXCOORD0;
				UNITY_FOG_COORDS(1)
				//rim  
				float3 normal: TEXCOORD2;     
				float3 viewDir: TEXCOORD3;  
			};

			v2f vert(appdata_base v)
			{
				v2f o;
				o.sv_pos = mul(UNITY_MATRIX_MVP, v.vertex);
				UNITY_TRANSFER_FOG(o,o.sv_pos);
				o.uv = v.texcoord;
				//
				o.normal = v.normal;
				o.viewDir = ObjSpaceViewDir(v.vertex).xyz;
				return o;
			}
			 
			sampler2D _MainTex;
			fixed	_MixPower;
			fixed4	_MixColor;

			fixed4  _RimColor;
			fixed   _RimStrength;
			fixed   _GrayPower;

			fixed4 frag(v2f i): SV_Target
			{
				fixed4 c = tex2D(_MainTex, i.uv);

				//灰度值
				fixed gray = dot(c.rgb, fixed3(0.3, 0.6, 0.1));

				//灰度增强
				c.rgb += gray.r * c.rgb * _GrayPower;

				//fog颜色处理
				UNITY_APPLY_FOG(i.fogCoord, c);

				//自定义混合色处理(目前用于闪白)
				c.rgb += gray.r * _MixPower * _MixColor.rgb * 2;

				//边缘高亮
				fixed dot_v = dot(i.normal, normalize(i.viewDir));
				c.rgb += _RimColor * pow(clamp(1 - dot_v, 0, 1), 1.3f) * 1.5f * _RimStrength;
				return c;
			}
			ENDCG
		}
		// Pass to render object as a shadow caster, required to write to depth texture
		Pass 
		{
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }
		}
    }
}
