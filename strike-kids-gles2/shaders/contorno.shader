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

// COR COMO NO GODOT 4 (medido): o shader de lá convertia as cores para luz
// linear e a cor que ele entregava ainda passava por sRGB -> linear e pelo
// "filmic" (branco 1,6) antes de virar sRGB. As mesmas contas aqui, por
// vértice, em versões sem potência (baratas na Mali-400/450).
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
	c = mix(vec3(lum), c, 1.14 + 0.34 * (1.0 - sat));
	return clamp(c * 1.08 - 0.045, 0.0, 1.0);
}

// a cor CRUA, como o shader do Godot 4 a entregava, até a tela: lá ela
// ainda passava por sRGB -> linear, "filmic" (branco 1,6) e linear -> sRGB
// (medido no Godot 4). Aqui numa conta só, sem potência nem divisão
// (erro < 2%; satura em 1,25, como lá)
vec3 tela_g4(vec3 x) {
	x = clamp(x, 0.0, 1.25);
	return viva(x * (1.2094 - x * (0.015 + 0.25 * x)));
}

void vertex() {
	vec4 pv = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float d = clamp(-pv.z, 0.8, 9.0);
	vec4 p = MODELVIEW_MATRIX * vec4(VERTEX + NORMAL * espessura * d, 1.0);
	p.xyz += normalize(p.xyz) * recuo * d;
	POSITION = PROJECTION_MATRIX * p;
	cor = tela_g4(mix(s2l(cor_contorno.rgb), s2l(COLOR.rgb) * 0.28, usa_cor_vertice));
}

void fragment() {
	ALBEDO = cor;
}
