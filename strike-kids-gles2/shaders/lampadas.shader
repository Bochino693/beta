shader_type spatial;
render_mode unshaded, cull_back;

// LÂMPADAS DO LETREIRO (MultiMesh). Cada lâmpada tem a cor da instância e
// um número em INSTANCE_CUSTOM.r; o padrão do pisca vem de `fase`
// (calculada na CPU). Tudo por vértice (a lâmpada é pequena).

uniform float fase = 0.0;
uniform int modo = 0;          // 0 corrida, 1 todas piscando, 2 alternado
uniform float intensidade = 1.6;

varying vec3 cor;


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
	float n = INSTANCE_CUSTOM.r;
	float on;
	if (modo == 0) {
		on = 0.25 + 0.75 * step(0.6, fract(n * 0.25 - fase));
	} else if (modo == 1) {
		on = 0.3 + 0.7 * step(0.5, fract(fase * 2.0));
	} else {
		on = 0.25 + 0.75 * step(0.5, fract(n * 0.5 + fase * 2.0));
	}
	vec3 pv = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 nv = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float rim = clamp(dot(nv, normalize(-pv)), 0.0, 1.0);
	cor = tela_g4(COLOR.rgb * (0.35 + rim * 0.65) * on * intensidade + vec3(0.12) * rim);
}

void fragment() {
	ALBEDO = cor;
}
