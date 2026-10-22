shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

// CANALETA DE CADA CENÁRIO (a mesma meia-cana; o desenho muda):
//   0 = doce listrado (Parque), 1 = metal de nave com luz correndo (Espaço),
//   2 = água com reflexos (Fundo do Mar), 3 = bambu com nós (Selva).
// Edição OpenGL ES 2.0: bordas suaves de largura fixa (sem derivadas) e as
// contas que dependem só da posição feitas por vértice.

uniform int modo = 0;
uniform vec4 cor_a : hint_color = vec4(1.0, 0.48, 0.72, 1.0);
uniform vec4 cor_b : hint_color = vec4(1.0, 0.95, 0.88, 1.0);
uniform vec4 cor_c : hint_color = vec4(1.0, 0.82, 0.25, 1.0);
uniform vec3 luz_cena = vec3(1.2, 1.2, 1.22);
uniform float centro = 0.8;      // |x| do meio de cada calha

varying float ux;
varying float z;
varying float labio;
varying float sombra;


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

// a cor CRUA, como o shader do Godot 4 a entregava, até a tela: lá ela
// ainda passava por sRGB -> linear, "filmic" (branco 1,6) e linear -> sRGB
// (medido no Godot 4). Aqui numa conta só, sem potência nem divisão
// (erro < 2%; satura em 1,25, como lá)
vec3 tela_g4(vec3 x) {
	x = clamp(x, 0.0, 1.25);
	return viva(x * (1.2094 - x * (0.015 + 0.25 * x)));
}

void vertex() {
	vec3 pw = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ux = abs(pw.x) - centro;
	z = pw.z;
	labio = smoothstep(-0.032, -0.012, pw.y);
	sombra = COLOR.r;
}

void fragment() {
	vec3 c;
	if (modo == 0) {
		float t = z * 2.4 + ux * 6.0;
		float m = clamp(0.5 - (abs(fract(t) - 0.5) - 0.25) * 40.0, 0.0, 1.0);
		c = mix(cor_b.rgb, cor_a.rgb, m);
		c = mix(c, cor_c.rgb, labio);
	} else if (modo == 1) {
		float ds = abs(fract(z * 2.0 + 0.5) - 0.5) * 0.5;
		float emenda = 1.0 - smoothstep(0.004, 0.008, ds);
		c = cor_a.rgb * (1.0 - 0.35 * emenda);
		float p = fract(z * 0.8 + TIME * 1.3);
		float q = (p - 0.5) * 9.0;
		float pulso = exp(-q * q) * (1.0 - smoothstep(0.02, 0.07, abs(ux)));
		float filete = 1.0 - smoothstep(0.004, 0.008, abs(ux));
		c += cor_c.rgb * (pulso * 1.1 + filete * 0.45);
		c = mix(c, cor_c.rgb * 1.15, labio);
	} else if (modo == 2) {
		float o = sin(z * 7.0 + sin(ux * 38.0 + TIME * 1.7) * 1.3 + TIME * 2.2);
		float reflexo = smoothstep(0.82, 0.92, o);
		c = mix(cor_a.rgb, cor_b.rgb, 0.25 + 0.35 * labio) + vec3(0.85, 1.0, 1.0) * reflexo * 0.35;
		c = mix(c, cor_c.rgb, labio);
	} else {
		float dn = abs(fract(z / 0.42 + 0.5) - 0.5) * 0.42;
		float no = 1.0 - smoothstep(0.011, 0.016, dn);
		float anel = 1.0 - smoothstep(0.007, 0.012, abs(dn - 0.03));
		float fibra = 0.9 + 0.1 * sin(ux * 95.0);
		c = cor_a.rgb * fibra;
		c = mix(c, cor_b.rgb, anel * 0.7);
		c = mix(c, cor_a.rgb * 0.45, no);
		c = mix(c, cor_c.rgb, labio);
	}
	// as mesmas contas do Godot 4 (cores cruas x luz da cena)
	ALBEDO = tela_g4(c * sombra * min(luz_cena, vec3(1.3)));
}
