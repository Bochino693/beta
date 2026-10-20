shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

// PISO DA ÁREA DOS JOGADORES: madeira envernizada, pontinhos coloridos e a
// estrela "pise aqui". Edição OpenGL ES 2.0: bordas suaves de largura fixa
// e o reflexo do céu (fresnel) com a direção da câmera vinda do vértice.

uniform sampler2D madeira : hint_albedo;
uniform vec2 escala_uv = vec2(4.2, 1.6);
uniform vec4 tom : hint_color = vec4(0.93, 0.84, 0.76, 1.0);
uniform vec3 luz_cena = vec3(1.2, 1.2, 1.22);
uniform vec4 cor_ceu : hint_color = vec4(0.85, 0.93, 1.0, 1.0);
uniform float verniz = 0.22;
uniform float pulso = 0.0;

varying vec3 pm;
varying vec3 olhar;

float cobre(float dist) {
	return clamp(0.5 - dist * 220.0, 0.0, 1.0);
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

vec3 adesivo(vec3 c, float dist, vec3 cor, float contorno) {
	c = mix(c, vec3(1.0), cobre(dist - contorno));
	return mix(c, cor, cobre(dist));
}

void vertex() {
	pm = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
	olhar = CAMERA_MATRIX[3].xyz - pm;
}

void fragment() {
	vec3 c = texture(madeira, UV * escala_uv).rgb * tom.rgb;
	if (abs(pm.z - 0.55) < 0.1 && abs(pm.x) < 0.62) {
		float ip = clamp(floor(pm.x / 0.17 + 0.5), -3.0, 3.0);
		float dd = length(vec2(pm.x - ip * 0.17, pm.z - 0.55)) - 0.032;
		vec3 cor = vec3(1.0, 0.23, 0.33);
		if (ip > -2.5) { cor = vec3(1.0, 0.56, 0.13); }
		if (ip > -1.5) { cor = vec3(1.0, 0.85, 0.15); }
		if (ip > -0.5) { cor = vec3(0.35, 0.86, 0.33); }
		if (ip > 0.5) { cor = vec3(0.2, 0.8, 1.0); }
		if (ip > 1.5) { cor = vec3(0.27, 0.47, 1.0); }
		if (ip > 2.5) { cor = vec3(0.72, 0.38, 1.0); }
		c = adesivo(c, dd, cor, 0.011);
	}
	if (abs(pm.z - 1.45) < 0.32 && abs(pm.x) < 0.32) {
		float de = sd_estrela(vec2(pm.x, 1.45 - pm.z), 0.2, 0.48) - 0.015;
		c += vec3(1.0, 0.85, 0.2) * exp(-max(de, 0.0) * 20.0) * (0.15 + 0.15 * pulso);
		c = adesivo(c, de, vec3(1.0, 0.82, 0.15), 0.02);
	}
	c *= sqrt(luz_cena);   // luz linear sobre cor da tela
	vec3 v = normalize(olhar);
	float f1 = 1.0 - clamp(v.y, 0.0, 1.0);
	float f2 = f1 * f1;
	ALBEDO = mix(c, cor_ceu.rgb, f2 * f2 * verniz);
}
