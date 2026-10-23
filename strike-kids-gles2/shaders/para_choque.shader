shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

// PARA-CHOQUES (bumpers) das canaletas: as listras de doce em espiral
// (doce_listrado.shader) e LUZES que correm por eles até os pinos, na cor
// do neon do cenário — junto com as bordas da pista (a mesma fase, vinda
// da CPU), mais fortes durante a jogada. A luz do cenário por vértice
// (Materiais.registrar). Umas contas a mais por pixel, nada de textura.

uniform vec4 cor_a : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cor_b : hint_color = vec4(1.0, 0.23, 0.31, 1.0);
uniform float listras_por_metro = 4.0;
uniform float giro = 1.0;            // voltas da espiral por listra
uniform float faixa : hint_range(0.0, 0.5) = 0.08;
uniform float borda : hint_range(0.0, 2.0) = 0.35;
uniform float especular : hint_range(0.0, 2.0) = 0.5;
uniform vec3 luz_dir = vec3(0.35, 0.8, 0.5);
uniform vec3 luz_cor = vec3(1.05, 0.935, 0.745);      // linear (Materiais.definir_luz)
uniform vec3 ambiente = vec3(0.212, 0.278, 0.439);
uniform vec4 cor_luz : hint_color = vec4(0.35, 0.85, 1.0, 1.0);
uniform float fase = 0.0;       // 0..1 (a mesma das bordas da pista)
uniform float luz = 0.0;        // 0..1: acende forte durante a jogada

varying vec3 luz_v;
varying vec3 soma;
varying float y_local;
varying float dist;             // distância da linha de falta (m)

// COR COMO NO GODOT 4: lá o motor já entregava a cor do vértice e as cores
// do material convertidas para luz linear e o shader convertia de novo
// (duas vezes: cores mais fechadas e vivas); e a imagem
// final passava pelo "filmic" (branco 1,6) antes de virar sRGB. As mesmas
// contas aqui, em versões sem potência (baratas na Mali-400/450).
vec3 s2l(vec3 c) {
	// sRGB -> linear sem potência (polinômio, erro ~1%): barato no vértice
	return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878);
}

// COR VIVA: realça mais as cores menos saturadas (céu, madeira, chão) e
// quase não mexe nas que já são fortes, com um pouco mais de contraste.
// Era uma passada a mais na tela inteira (tela3d.shader); aqui sai de
// graça, na mesma conta que entrega a cor (as mesmas contas de lá).
vec3 viva(vec3 c) {
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	c = mix(vec3(lum), c, 1.08 + 0.32 * (1.0 - sat));
	return clamp(c * 1.07 - 0.035, 0.0, 1.0);
}

vec3 tela(vec3 x) {
	// "filmic" (branco 1,6) + sRGB numa conta só, sem potência (erro < 3%)
	x = max(x, vec3(0.0));
	return viva(min(sqrt(x) * (1.29 - 0.1 * x) / (1.0 + 0.25 * x), vec3(1.0)));
}

vec3 tela_rapida(vec3 x) {
	x = max(x, vec3(0.0));
	return viva(min(sqrt(x) * (1.29 - 0.1 * x) / (1.0 + 0.25 * x), vec3(1.0)));
}

void vertex() {
	y_local = VERTEX.y;
	dist = -(WORLD_MATRIX * vec4(VERTEX, 1.0)).z;
	vec3 n = normalize((WORLD_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float t = smoothstep(-faixa, faixa, dot(n, normalize(luz_dir)) - 0.02);
	vec3 l = luz_cor * t + ambiente;
	vec3 pv = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 nv = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v = normalize(-pv);
	float r1 = 1.0 - clamp(dot(nv, v), 0.0, 1.0);
	float rim = r1 * r1 * r1;
	vec3 lv = normalize((INV_CAMERA_MATRIX * vec4(luz_dir, 0.0)).xyz);
	float sp = smoothstep(0.93, 0.95, dot(nv, normalize(v + lv)));
	luz_v = l + vec3(rim * borda);
	soma = luz_cor * sp * especular * 0.5;
}

void fragment() {
	float ang = -0.25 - UV.x;
	float s = fract(y_local * listras_por_metro + ang * giro) - 0.5;
	float m = clamp(0.5 - (abs(s) - 0.25) * 30.0, 0.0, 1.0);
	vec3 base = mix(cor_a.rgb, cor_b.rgb, m);
	// a luz que corre (a mesma conta das bordas de neon da pista)
	float fr = fract(dist * 1.1 - fase);
	float corre = smoothstep(0.42, 0.58, fr) * smoothstep(0.98, 0.84, fr);
	vec3 neon = cor_luz.rgb * cor_luz.rgb;
	vec3 c = base * base * luz_v + soma;
	// na faixa acesa o doce vira a cor do neon (brilhando)
	c = mix(c, neon * 1.7 + vec3(0.18), corre * (0.6 + 0.3 * luz));
	ALBEDO = tela_rapida(c);
}
