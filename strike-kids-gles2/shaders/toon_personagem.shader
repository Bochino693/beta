shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// TOON DOS PERSONAGENS E PINOS — edição OpenGL ES 2.0 (Mali-400/450).
// O mesmo toon (luz por vértice, rosto projetado de frente) com:
//  * escuro: escurece tudo (o pino caindo no poço do alçapão);
//  * ESTAMPA DA ROUPA desenhada aqui (não na malha):
//      1 = estrela de frente no peito; 2 = bolinhas em fileiras na saia;
//      3 = listras (camiseta de pirata).
//    Só aparece onde a cor do vértice é a da roupa (estampa_base). A borda
//    do desenho é suavizada com uma largura fixa (sem derivadas: a placa
//    OpenGL ES 2 nem sempre tem).

uniform vec4 tinta : hint_color = vec4(1.0);
uniform float faixa : hint_range(0.0, 0.5) = 0.06;
uniform float luz_minima : hint_range(0.0, 1.0) = 0.0;
uniform float borda : hint_range(0.0, 2.0) = 0.35;
uniform vec4 cor_borda : hint_color = vec4(1.0, 0.95, 0.9, 1.0);
uniform float especular : hint_range(0.0, 2.0) = 0.0;
uniform float tamanho_especular : hint_range(0.5, 0.999) = 0.92;
uniform vec4 emissao : hint_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float escuro : hint_range(0.0, 1.0) = 1.0;
uniform float brilho_luz : hint_range(0.0, 4.0) = 1.4;

uniform bool usa_rosto = false;
uniform sampler2D rosto : hint_albedo;
uniform vec2 rosto_centro = vec2(0.0, 0.235);
uniform vec2 rosto_tamanho = vec2(0.46, 0.40);
uniform vec2 rosto_grade = vec2(4.0, 2.0);
uniform vec2 rosto_celula = vec2(0.0, 0.0);

uniform int estampa = 0;
uniform vec4 estampa_base : hint_color = vec4(1.0);
uniform vec4 estampa_cor : hint_color = vec4(1.0, 0.85, 0.2, 1.0);
uniform vec2 estampa_centro = vec2(0.0, 0.1);
uniform float estampa_raio = 0.06;
uniform float estampa_dentro = 0.5;
uniform float bolinhas_y0 = -0.05;
uniform float bolinhas_dy = 0.05;
uniform int bolinhas_fileiras = 3;
uniform int bolinhas_n0 = 12;
uniform float bolinhas_y_max = 0.08;

uniform vec3 luz_dir = vec3(0.35, 0.8, 0.5);
uniform vec3 luz_cor = vec3(1.05, 0.935, 0.745);      // linear (Materiais.definir_luz)
uniform vec3 ambiente = vec3(0.212, 0.278, 0.439);

varying vec3 cor;
varying vec3 luz_lin;
// uv do rosto (xy), máscara do rosto (z), máscara do tecido (w): juntos,
// para caber nas poucas variáveis da Mali-400
varying vec4 rosto_v;
varying vec3 pos_local;

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
	c = mix(vec3(lum), c, 1.14 + 0.34 * (1.0 - sat));
	return clamp(c * 1.08 - 0.045, 0.0, 1.0);
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

float sd_estrela(vec2 p, float r, float vale) {
	vec2 k1 = vec2(0.809016994375, -0.587785252292);
	vec2 k2 = vec2(-0.809016994375, -0.587785252292);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = vale * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

float sd_bolinhas(vec3 p) {
	float melhor = 1000.0;
	float raio_h = max(length(p.xz), 0.0001);
	float ang = atan(p.x, p.z);
	for (int k = 0; k < 6; k++) {
		if (k >= bolinhas_fileiras) {
			break;
		}
		float fk = float(k);
		float y = bolinhas_y0 + fk * bolinhas_dy;
		float n = float(bolinhas_n0) - fk;
		float desloc = 0.5 * mod(fk, 2.0);
		float passo = 6.28318531 / n;
		float i = floor(ang / passo - desloc + 0.5);
		float d_ang = ang - (i + desloc) * passo;
		vec2 q = vec2(d_ang * raio_h, p.y - y);
		melhor = min(melhor, length(q) - estampa_raio);
	}
	return melhor;
}

void vertex() {
	vec3 base = s2l(s2l(COLOR.rgb)) * s2l(s2l(tinta.rgb));
	vec3 n = normalize((WORLD_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float ndl = dot(n, normalize(luz_dir));
	float t = smoothstep(-faixa, faixa, ndl - 0.02);
	vec3 l = luz_cor * max(t, luz_minima) + ambiente;
	vec3 pv = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 nv = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v = normalize(-pv);
	float r1 = 1.0 - clamp(dot(nv, v), 0.0, 1.0);
	float rim = r1 * r1 * r1;
	vec3 soma = s2l(s2l(cor_borda.rgb)) * borda * rim * base + s2l(s2l(emissao.rgb)) + vec3(flash) * base;
	float brilho = 1.0 - clamp(abs(COLOR.a - 0.5) * 5.0, 0.0, 1.0);
	soma += base * brilho * brilho_luz;
	if (especular > 0.0) {
		vec3 lv = normalize((INV_CAMERA_MATRIX * vec4(luz_dir, 0.0)).xyz);
		float s = smoothstep(tamanho_especular, tamanho_especular + 0.02, dot(nv, normalize(v + lv)));
		soma += luz_cor * s * especular;
	}
	cor = tela((base * l + soma) * escuro);
	luz_lin = l * escuro;
	vec2 uv = (VERTEX.xy - rosto_centro) / rosto_tamanho + 0.5;
	float tecido = 1.0 - smoothstep(0.05, 0.12, distance(s2l(COLOR.rgb), s2l(estampa_base.rgb)));
	if (estampa == 1) {
		tecido *= smoothstep(0.15, 0.4, NORMAL.z);
	}
	rosto_v = vec4(uv.x, 1.0 - uv.y, smoothstep(0.75, 0.95, COLOR.a) * smoothstep(0.05, 0.3, NORMAL.z), tecido);
	pos_local = VERTEX;
}

void fragment() {
	vec3 c = cor;
	float mascara_rosto = rosto_v.z;
	float tecido = rosto_v.w;
	if (usa_rosto && mascara_rosto > 0.01) {
		vec2 uv = rosto_v.xy;
		if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
			vec4 f = texture(rosto, (clamp(uv, 0.004, 0.996) + rosto_celula) / rosto_grade);
			c = mix(c, tela_rapida(f.rgb * f.rgb * luz_lin), f.a * mascara_rosto);
		}
	}
	if (estampa > 0 && tecido > 0.01) {
		float d = 1000.0;
		float lado = 1.0;
		if (estampa == 1) {
			d = sd_estrela(pos_local.xy - estampa_centro, estampa_raio, estampa_dentro) - estampa_raio * 0.06;
			lado = step(0.0, pos_local.z);
		} else if (estampa == 2) {
			d = sd_bolinhas(pos_local);
			lado = 1.0 - smoothstep(bolinhas_y_max - 0.01, bolinhas_y_max, pos_local.y);
		} else {
			float y = pos_local.y - bolinhas_y0;
			d = abs(y - bolinhas_dy * floor(y / bolinhas_dy + 0.5)) - estampa_raio;
			lado = (1.0 - smoothstep(bolinhas_y_max - 0.01, bolinhas_y_max, pos_local.y)) * step(-estampa_raio, y);
		}
		// borda suave de ~1,5 mm (fixa: sem derivadas)
		float m = (1.0 - smoothstep(-0.0015, 0.0015, d)) * tecido * lado;
		// (no Godot 4 a cor da estampa e a tinta eram convertidas duas vezes)
		vec3 ec = estampa_cor.rgb * tinta.rgb;
		vec3 e2 = ec * ec;
		vec3 ce = tela_rapida(e2 * e2 * luz_lin);
		c = mix(c, ce, m);
	}
	ALBEDO = c;
}
