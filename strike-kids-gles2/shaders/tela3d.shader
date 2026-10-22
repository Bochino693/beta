shader_type canvas_item;

// A IMAGEM 3D NA TELA (modo "imagem" — o compatível; no modo direto, o
// normal, o 3D é desenhado direto na tela e isto nem existe): esticada até
// a tela inteira quando a imagem 3D é desenhada menor que a tela. A cor
// viva já vem pronta de cada desenho 3D (viva() nos shaders).
//
// NITIDEZ (só no PC, só quando a imagem 3D está menor que a tela): realce
// de bordas adaptativo (como o "CAS" da AMD): devolve a definição que o
// esticar tira, sem criar halos. Na TV Box fica desligado (custaria 5
// leituras por pixel).

uniform float nitidez = 0.0;      // 0 = desligado; 0,3..0,6 = realce

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	if (nitidez > 0.0) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		vec3 n = texture(TEXTURE, UV + vec2(0.0, -px.y)).rgb;
		vec3 s = texture(TEXTURE, UV + vec2(0.0, px.y)).rgb;
		vec3 l = texture(TEXTURE, UV + vec2(-px.x, 0.0)).rgb;
		vec3 r = texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb;
		vec3 mn = min(c, min(min(n, s), min(l, r)));
		vec3 mx = max(c, max(max(n, s), max(l, r)));
		// quanto realçar: menos onde já há muito contraste (sem halos)
		vec3 amp = sqrt(clamp(min(mn, 1.0 - mx) / max(mx, vec3(1e-4)), 0.0, 1.0));
		vec3 w = -amp * nitidez * 0.2;
		c = clamp((c + (n + s + l + r) * w) / (1.0 + 4.0 * w), 0.0, 1.0);
	}
	COLOR = vec4(c, 1.0);
}
