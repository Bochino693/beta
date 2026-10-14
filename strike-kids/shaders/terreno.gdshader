shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// TERRENO DOS CENÁRIOS — o desenho do chão é calculado aqui, pixel a pixel,
// pela posição no mundo: fica nítido em qualquer resolução (até 4K), sem
// os "degraus" de cor pintada nos vértices.
//   modo 0 parque: grama listrada (corte de grama) + florzinhas
//   modo 1 espaço: chão de lua com crateras + poeira brilhante
//   modo 2 mar:    areia com ondinhas + conchinhas
//   modo 3 selva:  verde fechado com manchas de terra + flores
// Luz toon igual à do resto do jogo (duas faixas).

uniform int modo = 0;
uniform vec4 cor_a : source_color = vec4(0.42, 0.80, 0.36, 1.0);
uniform vec4 cor_b : source_color = vec4(0.36, 0.72, 0.31, 1.0);
uniform vec4 cor_c : source_color = vec4(1.0, 0.62, 0.82, 1.0);   // detalhe 1 (flor, borda da cratera, concha...)
uniform vec4 cor_d : source_color = vec4(1.0, 0.92, 0.45, 1.0);   // detalhe 2
uniform float faixa : hint_range(0.0, 0.5) = 0.25;
uniform float luz_minima : hint_range(0.0, 1.0) = 0.0;

varying vec3 pos_mundo;

vec3 lin(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

float h2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 h22(vec2 p) {
	return vec2(h2(p), h2(p + 17.13));
}

// degrau sem serrilhado (largura de 1 pixel)
float aa(float d) {
	float w = fwidth(d) * 0.75 + 1e-5;
	return clamp(0.5 - d / w, 0.0, 1.0);
}

// bolinhas espalhadas numa grade: devolve cobertura (0..1) e um sorteio
vec2 pontos(vec2 p, float grade, float chance, float raio) {
	vec2 cel = floor(p / grade);
	float cob = 0.0;
	float sorte = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = cel + vec2(float(i), float(j));
			float r = h2(c * 1.31);
			if (r > chance) {
				vec2 centro = (c + 0.2 + 0.6 * h22(c)) * grade;
				float d = length(p - centro) - raio * (0.7 + 0.6 * fract(r * 13.0));
				float a = aa(d);
				if (a > cob) {
					cob = a;
					sorte = fract(r * 7.0);
				}
			}
		}
	}
	return vec2(cob, sorte);
}

void vertex() {
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = pos_mundo.xz;
	float alt = clamp(pos_mundo.y / 4.0, 0.0, 1.0);
	vec3 a = cor_a.rgb;
	vec3 b = cor_b.rgb;
	vec3 c;
	if (modo == 0) {
		// listras do corte de grama (bordas suaves de 1 pixel)
		float s = fract((p.y + p.x * 0.15) / 4.4) - 0.5;
		float lista = aa(abs(s) - 0.25);
		c = mix(a, b, lista);
		vec2 f = pontos(p, 0.9, 0.9, 0.06);
		c = mix(c, mix(cor_c.rgb, cor_d.rgb, step(0.5, f.y)), f.x);
	} else if (modo == 1) {
		c = a;
		vec2 cel = floor(p / 3.2);
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 q = cel + vec2(float(i), float(j));
				float r = h2(q * 2.7);
				if (r > 0.45) {
					vec2 centro = (q + 0.25 + 0.5 * h22(q)) * 3.2;
					float raio = 0.5 + 0.9 * fract(r * 9.0);
					float d = length(p - centro);
					c = mix(c, b, aa(d - raio));                         // fundo da cratera
					c = mix(c, cor_c.rgb, aa(abs(d - raio * 1.08) - raio * 0.08));   // bordinha clara
				}
			}
		}
		vec2 f = pontos(p, 0.7, 0.93, 0.025);
		c = mix(c, cor_d.rgb, f.x);
	} else if (modo == 2) {
		float onda = sin(p.x * 1.6 + sin(p.y * 0.35) * 2.0) * 0.5 + 0.5;
		c = mix(a, b, smoothstep(0.35, 0.65, onda));
		vec2 f = pontos(p, 1.1, 0.88, 0.045);
		c = mix(c, mix(cor_c.rgb, cor_d.rgb, step(0.5, f.y)), f.x);
	} else {
		float m = sin(p.x * 0.45 + 1.3) * sin(p.y * 0.38) + 0.5 * sin(p.x * 1.1 - p.y * 0.9);
		c = mix(b, a, aa(-m));
		c = mix(c, cor_d.rgb * vec3(0.72, 0.6, 0.45), aa(1.05 - m));   // terra
		vec2 f = pontos(p, 1.0, 0.9, 0.055);
		c = mix(c, mix(cor_c.rgb, cor_d.rgb, step(0.5, f.y)), f.x);
	}
	c *= 1.0 + 0.1 * alt;
	ALBEDO = lin(c);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(-faixa, faixa, ndl - 0.02);
	float luz = max(t * ATTENUATION, luz_minima);
	DIFFUSE_LIGHT += LIGHT_COLOR * luz / PI;
}
