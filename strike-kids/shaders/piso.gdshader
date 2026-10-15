shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back, shadows_disabled;

// PISO DE MADEIRA da área de quem joga: o mesmo verniz "desenhado" da
// pista (cor da cena + reflexo do céu), leve — cobre a tela quando a
// câmera olha para o mascote.

uniform sampler2D madeira : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 escala_uv = vec2(4.2, 1.6);
uniform vec3 tom : source_color = vec3(0.93, 0.84, 0.76);
uniform vec3 luz_cena = vec3(1.2, 1.2, 1.22);
uniform vec3 cor_ceu : source_color = vec3(0.85, 0.93, 1.0);
uniform float verniz = 0.22;

varying vec3 pm;

void vertex() {
	pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = texture(madeira, UV * escala_uv).rgb * tom * luz_cena;
	vec3 v = normalize(CAMERA_POSITION_WORLD - pm);
	float fres = pow(1.0 - clamp(v.y, 0.0, 1.0), 4.0);
	ALBEDO = mix(c, cor_ceu, fres * verniz);
}
