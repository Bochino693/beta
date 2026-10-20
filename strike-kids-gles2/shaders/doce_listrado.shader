shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

// DOCE LISTRADO (bengalas, pirulitos): listras em espiral pela posição
// local, com a luz do cenário por vértice (Materiais.registrar).

uniform vec4 cor_a : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cor_b : hint_color = vec4(1.0, 0.23, 0.31, 1.0);
uniform float listras_por_metro = 4.0;
uniform float giro = 1.0;            // voltas da espiral por listra
uniform float faixa : hint_range(0.0, 0.5) = 0.08;
uniform float borda : hint_range(0.0, 2.0) = 0.35;
uniform float especular : hint_range(0.0, 2.0) = 0.5;
uniform vec3 luz_dir = vec3(0.35, 0.8, 0.5);
uniform vec4 luz_cor : hint_color = vec4(1.0, 0.97, 0.92, 1.0);
uniform vec4 ambiente : hint_color = vec4(0.45, 0.45, 0.55, 1.0);

varying vec3 luz;
varying vec3 soma;
varying float y_local;

void vertex() {
	y_local = VERTEX.y;
	vec3 n = normalize((WORLD_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float t = smoothstep(-faixa, faixa, dot(n, normalize(luz_dir)) - 0.02);
	vec3 l = luz_cor.rgb * luz_cor.rgb * t + ambiente.rgb * ambiente.rgb;
	vec3 pv = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 nv = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v = normalize(-pv);
	float rim = pow(1.0 - clamp(dot(nv, v), 0.0, 1.0), 3.0);
	vec3 lv = normalize((INV_CAMERA_MATRIX * vec4(luz_dir, 0.0)).xyz);
	float sp = smoothstep(0.93, 0.95, dot(nv, normalize(v + lv)));
	luz = sqrt(l + vec3(rim * borda));
	soma = luz_cor.rgb * sp * especular * 0.5;
}

void fragment() {
	float ang = -0.25 - UV.x;
	float s = fract(y_local * listras_por_metro + ang * giro) - 0.5;
	float m = clamp(0.5 - (abs(s) - 0.25) * 30.0, 0.0, 1.0);
	vec3 base = mix(cor_a.rgb, cor_b.rgb, m);
	ALBEDO = base * luz + soma;
}
