shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

// CONTORNO (casca invertida). Na edição OpenGL ES 2.0 os contornos ficam
// desligados (Materiais.contornos_ligados): desenhariam cada peça 2 vezes.

uniform float espessura = 0.0035;
uniform vec4 cor_contorno : hint_color = vec4(0.17, 0.10, 0.27, 1.0);

void vertex() {
	VERTEX += NORMAL * espessura;
}

void fragment() {
	ALBEDO = cor_contorno.rgb;
}
