shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, fog_disabled;

// CONTORNO (casca invertida): a malha é inflada ao longo da normal e
// desenhada só por dentro. A espessura acompanha a distância, para o traço
// ficar com a mesma grossura na tela de perto e de longe.

uniform float espessura = 0.0035;
uniform vec4 cor_contorno : source_color = vec4(0.17, 0.10, 0.27, 1.0);
uniform float usa_cor_vertice : hint_range(0.0, 1.0) = 0.55;

vec3 srgb_para_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	vec4 pv = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float d = -pv.z;
	VERTEX += NORMAL * espessura * clamp(d, 0.8, 9.0);
}

void fragment() {
	vec3 escura = srgb_para_linear(COLOR.rgb) * 0.28;
	ALBEDO = mix(srgb_para_linear(cor_contorno.rgb), escura, usa_cor_vertice);
}
