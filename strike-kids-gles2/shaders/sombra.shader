shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// SOMBRA REDONDA (blob) embaixo de bola, pinos e personagens: dá a noção de
// altura (o 3D "salta") e custa quase nada.

uniform sampler2D textura : hint_albedo;
uniform float forca = 0.55;

void fragment() {
	vec4 t = texture(textura, UV);
	ALBEDO = t.rgb;
	// no Godot 4 a mistura era em luz linear: a mesma escuridão, misturando
	// na cor da tela, pede menos opacidade
	float a = clamp(t.a * forca * COLOR.a, 0.0, 1.0);
	ALPHA = 1.0 - pow(1.0 - a, 0.4545);
}
