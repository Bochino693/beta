shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

// CONTORNO (casca invertida): a malha é inflada ao longo da normal e
// desenhada só por dentro. A espessura acompanha a distância, para o traço
// ficar com a mesma grossura na tela de perto e de longe.
// RECUO: a casca é empurrada um pouquinho para longe da câmera. Contra o
// fundo o traço continua igual, mas onde uma peça encosta em outra (manga
// no ombro, lenço na camiseta) o traço fica escondido atrás dela — sem
// "costuras" riscadas por cima da roupa.
// Edição OpenGL ES 2.0: só nos bichinhos, pinos e peças da pista (a
// decoração do cenário não tem); a cor sai pronta do vértice.

uniform float espessura = 0.0035;
uniform float recuo = 0.015;
uniform vec4 cor_contorno : hint_color = vec4(0.17, 0.10, 0.27, 1.0);
uniform float usa_cor_vertice : hint_range(0.0, 1.0) = 0.55;

varying vec3 cor;

// COR COMO NO GODOT 4: lá o motor já entregava a cor do vértice e as cores
// do material convertidas para luz linear e o shader convertia de novo
// (duas vezes: cores mais fechadas e vivas); e a imagem
// final passava pelo "filmic" (branco 1,6) antes de virar sRGB. As mesmas
// contas aqui (por vértice; no fragmento, a curva aproximada, erro < 3%).
vec3 s2l(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 tela(vec3 x) {
	x = max(x, vec3(0.0));
	vec3 f = clamp(((x * (0.88 * x + 0.06) + 0.002) / (x * (0.88 * x + 0.6) + 0.06) - 0.033333) / 0.68495, 0.0, 1.0);
	return mix(f * 12.92, 1.055 * pow(f, vec3(0.416667)) - 0.055, step(vec3(0.0031308), f));
}

vec3 tela_rapida(vec3 x) {
	x = max(x, vec3(0.0));
	return min(sqrt(x) * (1.29 - 0.1 * x) / (1.0 + 0.25 * x), vec3(1.0));
}

void vertex() {
	vec4 pv = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float d = clamp(-pv.z, 0.8, 9.0);
	vec4 p = MODELVIEW_MATRIX * vec4(VERTEX + NORMAL * espessura * d, 1.0);
	p.xyz += normalize(p.xyz) * recuo * d;
	POSITION = PROJECTION_MATRIX * p;
	cor = tela(mix(s2l(s2l(cor_contorno.rgb)), s2l(s2l(COLOR.rgb)) * 0.28, usa_cor_vertice));
}

void fragment() {
	ALBEDO = cor;
}
