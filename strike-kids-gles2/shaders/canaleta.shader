shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

// CANALETA DE CADA CENÁRIO — os efeitos ficam aqui, POR BAIXO dos
// para-choques (a mesma meia-cana; o desenho muda):
//   0 = doce listrado com luzinhas correndo para os pinos (Parque),
//   1 = metal de nave com rebites e luzes que correm (Espaço),
//   2 = água com reflexos e bolhinhas indo para os pinos (Fundo do Mar),
//   3 = bambu com nós, fibras e um brilho verde correndo (Selva).
// Edição OpenGL ES 2.0 (Mali-450): as CORES já saem prontas do vértice (a
// conta da tela — tela_g4 — é cara e era feita em cada pixel); o pixel só
// mistura as três cores da calha e soma os efeitos. Bordas suaves de
// largura fixa (sem derivadas) e o TEMPO vindo da CPU já dentro de uma
// volta (fase, onda1, onda2, bolhas): o pixel da Mali-450 é de meia
// precisão e o TIME, depois de uns minutos, andava aos saltos.

uniform int modo = 0;
uniform vec4 cor_a : hint_color = vec4(1.0, 0.48, 0.72, 1.0);
uniform vec4 cor_b : hint_color = vec4(1.0, 0.95, 0.88, 1.0);
uniform vec4 cor_c : hint_color = vec4(1.0, 0.82, 0.25, 1.0);
uniform vec3 luz_cena = vec3(1.2, 1.2, 1.22);
uniform float centro = 0.8;      // |x| do meio de cada calha
uniform float fase = 0.0;        // 0..1: as luzes que correm (espaço)
uniform float onda1 = 0.0;       // 0..2pi: os reflexos da água
uniform float onda2 = 0.0;
uniform float bolhas = 0.0;      // 0..3,52 m: as bolhinhas andando

// as cores da calha já na tela (com a luz e o sombreado do vértice)
varying vec3 ta;
varying vec3 tb;
varying vec3 tc;
// x: distância do meio da calha, y: z (ao longo da pista), z: lábio
varying vec3 pos_c;


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
	vec3 pw = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
	pos_c = vec3(abs(pw.x) - centro, pw.z, smoothstep(-0.032, -0.012, pw.y));
	vec3 luz = COLOR.r * min(luz_cena, vec3(1.3));
	ta = tela_g4(cor_a.rgb * luz);
	tb = tela_g4(cor_b.rgb * luz);
	tc = tela_g4(cor_c.rgb * luz);
}

// luzinhas que correm pelo meio da calha até os pinos (a cada 1,25 m)
float pulso(float ux, float z, float largura) {
	float q = (fract(z * 0.8 + fase) - 0.5) * 9.0;
	return exp(-q * q) * (1.0 - smoothstep(largura * 0.4, largura, abs(ux)));
}

void fragment() {
	float ux = pos_c.x;
	float z = pos_c.y;
	float labio = pos_c.z;
	vec3 c;
	if (modo == 0) {
		float t = z * 2.4 + ux * 6.0;
		float m = clamp(0.5 - (abs(fract(t) - 0.5) - 0.25) * 40.0, 0.0, 1.0);
		c = mix(tb, ta, m);
		c += tc * pulso(ux, z, 0.06) * 0.9;
		c = mix(c, tc, labio);
	} else if (modo == 1) {
		// painéis de 0,5 m com emenda e rebites dos lados
		float ds = abs(fract(z * 2.0 + 0.5) - 0.5) * 0.5;
		float emenda = 1.0 - smoothstep(0.004, 0.008, ds);
		float rebite = 1.0 - smoothstep(0.006, 0.01, length(vec2(abs(ux) - 0.1, ds - 0.06)));
		c = ta * (1.0 - 0.35 * emenda) + tb * 0.4 * rebite;
		float filete = 1.0 - smoothstep(0.004, 0.008, abs(ux));
		c += tc * (pulso(ux, z, 0.07) * 1.1 + filete * 0.45);
		c = mix(c, tc, labio);
	} else if (modo == 2) {
		float o = sin(z * 7.0 + sin(ux * 38.0 + onda1) * 1.3 + onda2);
		float reflexo = smoothstep(0.82, 0.92, o);
		c = mix(ta, tb, 0.25 + 0.35 * labio) + vec3(0.8, 0.95, 0.95) * reflexo * 0.3;
		// bolhinhas: uma por célula (0,08 x 0,22 m), indo devagar para os
		// pinos (o sorteio repete a cada 16 células: a volta de `bolhas`)
		vec2 bq = vec2(ux / 0.08, (z + bolhas) / 0.22);
		vec2 cel = floor(bq);
		float h = fract(cel.x * 0.618 + mod(cel.y, 16.0) * 0.7548 + cel.x * mod(cel.y, 16.0) * 0.137);
		vec2 cb = cel + vec2(0.25 + 0.5 * h, 0.2 + 0.6 * fract(h * 7.3));
		vec2 db = (bq - cb) * vec2(0.08, 0.22);
		float raio = 0.007 + 0.009 * fract(h * 13.1);
		float bolha = (1.0 - smoothstep(0.0015, 0.0035, abs(length(db) - raio))) * step(0.45, h);
		c = mix(c, vec3(0.92, 1.0, 1.0), bolha * 0.85);
		c = mix(c, tc, labio);
	} else {
		float dn = abs(fract(z / 0.42 + 0.5) - 0.5) * 0.42;
		float no = 1.0 - smoothstep(0.011, 0.016, dn);
		float anel = 1.0 - smoothstep(0.007, 0.012, abs(dn - 0.03));
		float fibra = 0.9 + 0.1 * sin(ux * 95.0 + sin(z * 2.7) * 0.6);
		c = ta * fibra;
		c = mix(c, tb, anel * 0.7);
		c = mix(c, ta * 0.45, no);
		c += vec3(0.55, 0.9, 0.25) * pulso(ux, z, 0.07) * 0.6;
		c = mix(c, tc, labio);
	}
	ALBEDO = c;
}
