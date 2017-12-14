Shader "MW/Player_New" {
    Properties {
        _MainTex ("MainTex", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)
		_MixPower ("_Mix Power", Range(0,.9)) = 0
		_MixColor ("_Mix Color", Color) = (0,0,0,1)

		_RimColor ("Rim Color", Color) = (0,0.545,1,1)
		_RimStrength ("Rim Strength", float) = 0

		_Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5 //光泽度(1-Roughness)，与常见的粗糙度等价，只是数值上更为直观，值越小越粗糙
		[Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0 //金属度，这两个值只有在没有_MetallicGlossMap贴图的情况下生效
		_MetallicGlossMap("Metallic", 2D) = "white" {}	//金属度与光泽度贴图，金属度在r通道上，光泽度在a通道上
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

			//PBR所需的参数
			sampler2D   _MainTex;
			half4		_Color;
			sampler2D	_MetallicGlossMap;
			half		_Metallic;
			half		_Glossiness;

			//自己添加的参数
			fixed	_MixPower;
			fixed4	_MixColor;
			fixed4  _RimColor;
			fixed   _RimStrength;
			

			half3 Albedo(float4 texcoords)
			{
				half3 albedo = _Color.rgb * tex2D (_MainTex, texcoords.xy).rgb;
				return albedo;
			}
			
			//
			half2 MetallicGloss(float2 uv)
			{
				half2 mg;
			#ifdef _METALLICGLOSSMAP
				mg = tex2D(_MetallicGlossMap, uv.xy).ra;
			#else
				mg = half2(_Metallic, _Glossiness);
			#endif
				return mg;
			}

			//ShaderLab中片段着色器用来传递数据的通用结构
			struct FragmentCommonData
			{
				half3 diffColor, specColor;
				// Note: oneMinusRoughness & oneMinusReflectivity for optimization purposes, mostly for DX9 SM2.0 level.
				// Most of the math is being done on these (1-x) values, and that saves a few precious ALU slots.
				half oneMinusReflectivity, oneMinusRoughness;
				half3 normalWorld, eyeVec, posWorld;
				half alpha;

			#if UNITY_OPTIMIZE_TEXCUBELOD || UNITY_STANDARD_SIMPLE
				half3 reflUVW;
			#endif

			#if UNITY_STANDARD_SIMPLE
				half3 tangentSpaceNormal;
			#endif
			};

			inline half OneMinusReflectivityFromMetallic(half metallic)
			{
				// We'll need oneMinusReflectivity, so
				//   1-reflectivity = 1-lerp(dielectricSpec, 1, metallic) = lerp(1-dielectricSpec, 0, metallic)
				// store (1-dielectricSpec) in unity_ColorSpaceDielectricSpec.a, then
				//	 1-reflectivity = lerp(alpha, 0, metallic) = alpha + metallic*(0 - alpha) = 
				//                  = alpha - metallic * alpha
				half oneMinusDielectricSpec = unity_ColorSpaceDielectricSpec.a;
				return oneMinusDielectricSpec - metallic * oneMinusDielectricSpec;
			}

			inline half3 DiffuseAndSpecularFromMetallic (half3 albedo, half metallic, out half3 specColor, out half oneMinusReflectivity)
			{
				specColor = lerp (unity_ColorSpaceDielectricSpec.rgb, albedo, metallic);
				oneMinusReflectivity = OneMinusReflectivityFromMetallic(metallic);
				return albedo * oneMinusReflectivity;
			}

			inline FragmentCommonData MetallicSetup (float4 i_tex)
			{
				half2 metallicGloss = MetallicGloss(i_tex.xy);
				half metallic = metallicGloss.x;
				half oneMinusRoughness = metallicGloss.y;		// this is 1 minus the square root of real roughness m.

				half oneMinusReflectivity;
				half3 specColor;
				half3 diffColor = DiffuseAndSpecularFromMetallic (Albedo(i_tex), metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);

				FragmentCommonData o = (FragmentCommonData)0;
				o.diffColor = diffColor;
				o.specColor = specColor;
				o.oneMinusReflectivity = oneMinusReflectivity;
				o.oneMinusRoughness = oneMinusRoughness;
				return o;
			} 

			struct v2f_meta
			{
				float4 uv		: TEXCOORD0;
				float4 pos		: SV_POSITION;
			};

			#define UNITY_SETUP_BRDF_INPUT MetallicSetup
			//计算每个像素上的世界坐标法线，如果有法线贴图则将法线贴图采样值混合进去
			half3 PerPixelWorldNormal(float4 i_tex, half4 tangentToWorld[3])
			{
#ifdef _NORMALMAP
				half3 tangent = tangentToWorld[0].xyz;
				half3 binormal = tangentToWorld[1].xyz;
				half3 normal = tangentToWorld[2].xyz;

#if UNITY_TANGENT_ORTHONORMALIZE
				normal = NormalizePerPixelNormal(normal);

				// ortho-normalize Tangent
				tangent = normalize(tangent - normal * dot(tangent, normal));

				// recalculate Binormal
				half3 newB = cross(normal, tangent);
				binormal = newB * sign(dot(newB, binormal));
#endif

				half3 normalTangent = NormalInTangentSpace(i_tex);
				half3 normalWorld = NormalizePerPixelNormal(tangent * normalTangent.x + binormal * normalTangent.y + normal * normalTangent.z); // @TODO: see if we can squeeze this normalize on SM2.0 as well
#else
				half3 normalWorld = normalize(tangentToWorld[2].xyz);
#endif
				return normalWorld;
			}

			inline FragmentCommonData FragmentSetup(float4 i_tex, half3 i_eyeVec, half3 i_viewDirForParallax, half4 tangentToWorld[3], half3 i_posWorld)
			{
				i_tex = Parallax(i_tex, i_viewDirForParallax);

				half alpha = Alpha(i_tex.xy);
#if defined(_ALPHATEST_ON)
				clip(alpha - _Cutoff);
#endif
				FragmentCommonData o = UNITY_SETUP_BRDF_INPUT(i_tex);
				o.normalWorld = PerPixelWorldNormal(i_tex, tangentToWorld);
				o.eyeVec = NormalizePerPixelNormal(i_eyeVec);
				o.posWorld = i_posWorld;

				// NOTE: shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
				o.diffColor = PreMultiplyAlpha(o.diffColor, alpha, o.oneMinusReflectivity, /*out*/ o.alpha);
				return o;
			}








			///////////////////////////////////////////////////
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

			fixed4 frag(v2f i): SV_Target
			{
				fixed4 c = tex2D(_MainTex, i.uv);

				//灰度值
				fixed gray = dot(c.rgb, fixed3(0.3, 0.6, 0.1));

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
