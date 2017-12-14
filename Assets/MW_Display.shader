Shader "MW/Display" {
    Properties {
        _MainTex ("MainTex", 2D) = "white" {}

		_PLight1Dir ("====Point Light 1 Dir====", Vector) = (-1,0.7,0.8,0)
		_PLight1Color ("Point Light 1 Color", Color) = (0.553, 0.553,0.553,0.49)

		_PLight2Dir ("====Point Light 2 Dir====", Vector) = (-0.13,0.85,-1.9,0)
		_PLight2Color ("Point Light 2 Color", Color) = (1, 0.76, 0.76, 0.11)

		_PLightAttenSq (">> Point Light AttenSq", float) = (0.4, 0, 0, 0)
		_PLightShadowStrength (">> Point Shadow Strength", float) = (0.3, 0, 0, 0)

		_LightDir1("=====Dir Light1", Vector) = (-6.55, 8.89,-17.64, -0.02)
		_LightColor1("Color Light1", Color) = (1, 0.94, 0.74, 0.28)
		_Power1("Power1", float) = 16

		_LightDir2("=====Dir Light2", Vector) = (-2, 0.2, 0.8, 0)
		_LightColor2("Color Light2", Color) = (0.275, 0.271, 0.361, 1)
		_Power2("Power2", float) = 20

		_LightDir3("=====Dir Light3", Vector) = (0.3, 0.4, -0.31, 0)
		_LightColor3("Color Light3", Color) = (0.47, 0.35, 0.13, 0.3)
		_Power3("Power3", float) = 20

		_HairUVx("Hair UVx", float) = 0.5
		_HairUVy("Hair UVy", float) = 0.38
		_Stencil("Stencil Tex", 2D) = "black" {}
		_BumpMap("FNormal Tex", 2D) = "black" {}
    }

	//两个点光源分别提亮
	//两个方向光出高光
	CGINCLUDE
		half3 Shade4PointLightsPower(
			half4 lightPosX, half4 lightPosY, half4 lightPosZ,
			half4 lightColor0, half4 lightColor1, half4 lightColor2, half4 lightColor3,
			half4 lightAttenSq, half4 shadowStrength,
			half3 pos, half3 normal)
		{
			// to light vectors
			half4 toLightX = lightPosX - pos.x;
			half4 toLightY = lightPosY - pos.y;
			half4 toLightZ = lightPosZ - pos.z;
			// squared lengths
			half4 lengthSq = 0;
			lengthSq += toLightX * toLightX;
			lengthSq += toLightY * toLightY;
			lengthSq += toLightZ * toLightZ;
			// NdotL
			half4 ndotl = 0;
			ndotl += toLightX * normal.x;
			ndotl += toLightY * normal.y;
			ndotl += toLightZ * normal.z;
			// correct NdotL
			half4 corr = rsqrt(lengthSq);
			half4 _dot = normalize(ndotl) * corr;
			half4 ndotl1 = max (half4(0,0,0,0), _dot);
			// attenuation
			half4 diff = ndotl1 * 1.0 / (1.0 + lengthSq * lightAttenSq);
			// final color
			half3 col = 0;
			col += lightColor0.rgb * diff.x * lightColor0.a * 4 - shadowStrength.rrr;
			col += lightColor1.rgb * diff.y * lightColor1.a * 4 - shadowStrength.ggg;
			col += lightColor2.rgb * diff.z * lightColor2.a * 4 - shadowStrength.bbb;
			col += lightColor3.rgb * diff.w * lightColor3.a * 4 - shadowStrength.aaa;
			return col;
		}
	ENDCG

    SubShader {
		//普通显示
		Pass{
			Tags 
			{
				//"Queue" = "Geometry+11"
				"LightMode"="ForwardBase"
			}
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog

			#include "UnityCG.cginc"
            #include "AutoLight.cginc"

			struct v2f{
				fixed4 sv_pos: SV_POSITION;
				float4 uv: TEXCOORD0;
				float4 PtColor: TEXCOORD1;
				half4 normalWorld : TEXCOORD2;  
				half4 add: TEXCOORD3;
				half4 add2: TEXCOORD4;
				//half3 posWorld: TEXCOORD3;
			};

			half4 _PLight1Dir;
			fixed4 _PLight1Color;

			half4 _PLight2Dir;
			fixed4 _PLight2Color;

			fixed4 _PLightAttenSq;
			fixed4 _PLightShadowStrength;

			sampler2D _Stencil;
			sampler2D _BumpMap;
			fixed _HairUVx;
			fixed _HairUVy;
			//sampler2D _UVAniTex;
			//float _UVAniSpeed;
			//float _stencilAlpha;
			//fixed4 _UVAniColor;

			v2f vert(appdata_tan v)
			{
				v2f o;
				o.sv_pos = mul(UNITY_MATRIX_MVP, v.vertex);
				o.uv = v.texcoord;
				half3 shadowColor;
				//点光源处理
				half4 PLightPosX = half4(_PLight1Dir.r, _PLight2Dir.r, 0, 0);
				half4 PLightPosY = half4(_PLight1Dir.g, _PLight2Dir.g, 0, 0);
				half4 PLightPosZ = half4(_PLight1Dir.b, _PLight2Dir.b, 0, 0);
				fixed3 PtLight = Shade4PointLightsPower(PLightPosX, PLightPosY, PLightPosZ,
					_PLight1Color, _PLight2Color, fixed4(0,0,0,0), fixed4(0,0,0,0),
					_PLightAttenSq, _PLightShadowStrength,
					v.vertex, v.normal);
				o.PtColor.rgb = PtLight;
				o.normalWorld.rgb = mul((half3x3)_Object2World, v.normal); 

				float3 posWorld = mul(_Object2World, v.vertex);
				o.uv.zw = posWorld.xy;
				o.PtColor.a = posWorld.z;

				v.normal = normalize(v.normal);
				v.tangent = normalize(v.tangent);
				TANGENT_SPACE_ROTATION;
				half3 c0 = mul(rotation, normalize(UNITY_MATRIX_IT_MV[0].xyz));
				half3 c1 = mul(rotation, normalize(UNITY_MATRIX_IT_MV[1].xyz));
				half3 c2 = mul(rotation, normalize(UNITY_MATRIX_IT_MV[2].xyz));
				o.add.xyz = c0;
				o.add2.xyz = c1;
				//节省
				o.normalWorld.a = c2.r;
				o.add.w = c2.g;
				o.add2.w = c2.b;
				return o;
			}
			 
			sampler2D _MainTex;

			half4 _LightDir1;
			fixed4 _LightColor1;

			half4 _LightDir2;
			fixed4 _LightColor2;

			half4 _LightDir3;
			fixed4 _LightColor3;

			fixed _Power1;
			fixed _Power2;
			fixed _Power3;

			fixed4 frag(v2f i): SV_Target
			{
				fixed4 oriC = tex2D(_MainTex, i.uv);
				fixed4 c = oriC;

				if(oriC.a < 0.5)
				{
					discard;
				}

				//点光				
				c.rgb += i.PtColor.rgb * oriC;
				//贴图细分
				fixed4 stencil = tex2D(_Stencil, i.uv.xy);
				fixed3 bump = UnpackNormal(tex2D(_BumpMap, i.uv * 8));
				fixed skinLightAtten = 1;
				fixed leatherNormalAtten = 1;
				fixed meaticLightAtten = 1;
				fixed meaticLightStrength = 1;
				//r通道>>金属 -- 加强高光
				meaticLightStrength = stencil.r * 10;
				meaticLightAtten = (1 - stencil.r);
				//g通道>>皮肤 -- 减弱高光影响
				skinLightAtten *= (1.5 - stencil.g);
				//b通道>>皮革 -- 质感法线材质
				leatherNormalAtten = stencil.b;
				half3 normalWorld = i.normalWorld.rgb;
				half3 add3 = half3(i.normalWorld.a, i.add.a, i.add2.a);
				half3 normal = normalize(half3(dot(i.add, bump), dot(i.add2, bump), dot(add3, bump)));
				//头发
				fixed2 temp_hair = fixed2(min(1, max(0, (i.uv.x) - _HairUVx) * 10), min(1, max(0, (1-i.uv.y) - _HairUVy) * 10));
				fixed hair = min(1, (temp_hair.x + temp_hair.y) * 10);
				//pos in world
				float3 posWorld = fixed3(i.uv.zw, i.PtColor.a);
				float3 viewDir = normalize(_WorldSpaceCameraPos - posWorld.xyz);
				//高光反射1 -- 处理质感法线
				float3 refl1 = normalize(reflect(normalize(-_LightDir1), normal));  
				fixed dot_v1 = max(0, dot(refl1, viewDir));
				c.rgb += pow(dot_v1, _Power1) * _LightColor1.rgb * _LightColor1.a * skinLightAtten * leatherNormalAtten * meaticLightAtten;
				//高光反射2 -- 体感光泽(头发皮肤皮革金属不参与)
				fixed dot_v2 = max(0, dot(normalize(-_LightDir2), normalize(normalWorld)));
				c.rgb += pow(dot_v2, _Power2) * _LightColor2.rgb * _LightColor2.a * skinLightAtten * meaticLightAtten * hair;
				//高光反射3 -- 金属(头发皮肤皮革不参与)
				float3 refl3 = normalize(reflect(normalize(-_LightDir3), normalize(normalWorld)));  
				fixed dot_v3 = max(0, dot(refl3, viewDir));
				c.rgb += pow(dot_v3, _Power3) * _LightColor3.rgb * _LightColor3.a * skinLightAtten * meaticLightStrength;
				//溜光
				//c.rgb *= (1 - stencil.r * _stencilAlpha);
				//c.rgb += c.rgb * stencil.r * tex2D(_UVAniTex, i.uv - _Time.y * _UVAniSpeed).r * _UVAniColor.rgb * 4;

				c.a = 1;
				return c;
			}

			ENDCG
		}
	}
}
