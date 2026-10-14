shader_type sky;

// CÉU: degradê azul -> horizonte claro, brilho do sol e um rosado no
// horizonte. Barato (nenhuma textura).

uniform vec3 cor_topo : source_color = vec3(0.20, 0.52, 1.0);
uniform vec3 cor_meio : source_color = vec3(0.45, 0.75, 1.0);
uniform vec3 cor_horizonte : source_color = vec3(1.0, 0.86, 0.95);
uniform vec3 cor_chao : source_color = vec3(0.55, 0.82, 0.55);
uniform vec3 dir_sol = vec3(0.35, 0.55, -0.75);
uniform vec3 cor_sol : source_color = vec3(1.0, 0.95, 0.75);

void sky() {
	vec3 d = normalize(EYEDIR);
	float y = d.y;
	vec3 c;
	if (y > 0.0) {
		c = mix(cor_horizonte, cor_meio, smoothstep(0.0, 0.18, y));
		c = mix(c, cor_topo, smoothstep(0.18, 0.75, y));
	} else {
		c = mix(cor_horizonte, cor_chao, smoothstep(0.0, -0.08, y));
	}
	float sol = max(dot(d, normalize(dir_sol)), 0.0);
	c += cor_sol * (pow(sol, 400.0) * 3.0 + pow(sol, 12.0) * 0.25);
	COLOR = c;
}
