shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// BOLA: textura (estrelas / corações) + luz em faixas + brilho de verniz
// (bolinha branca de reflexo) + borda iluminada. Edição OpenGL ES 2.0: a
// luz é calculada por vértice (a esfera tem 32 x 16 gomos), a placa só lê
// a textura.

uniform sampler2D textura : hint_albedo;
uniform float faixa = 0.08;
uniform float borda = 0.45;
uniform vec4 cor_borda : hint_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform float brilho = 1.6;
uniform float aceso : hint_range(0.0, 2.0) = 0.0;
// luz do cenário (Materiais.definir_luz)
uniform vec3 luz_dir = vec3(0.35, 0.8, 0.5);
uniform vec4 luz_cor : hint_color = vec4(1.0, 0.97, 0.92, 1.0);
uniform vec4 ambiente : hint_color = vec4(0.45, 0.45, 0.55, 1.0);

varying vec3 luz;
varying vec3 soma;
varying float acesa;

void vertex() {
	vec3 n = normalize((WORLD_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float t = smoothstep(-faixa, faixa, dot(n, normalize(luz_dir)));
	vec3 l = luz_cor.rgb * luz_cor.rgb * t + ambiente.rgb * ambiente.rgb;
	vec3 pv = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 nv = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v = normalize(-pv);
	float rim = pow(1.0 - clamp(dot(nv, v), 0.0, 1.0), 2.5);
	vec3 lv = normalize((INV_CAMERA_MATRIX * vec4(luz_dir, 0.0)).xyz);
	float s = smoothstep(0.94, 0.975, dot(nv, normalize(v + lv)));
	luz = sqrt(l);
	soma = cor_borda.rgb * rim * borda + luz_cor.rgb * s * brilho * 0.6;
	acesa = 1.0 + aceso * 0.6;
}

void fragment() {
	vec3 c = texture(textura, UV).rgb;
	ALBEDO = c * luz * acesa + soma;
}
