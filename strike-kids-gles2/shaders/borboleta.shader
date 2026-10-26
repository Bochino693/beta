shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled;

// BORBOLETA (detalhes extras, Temas._borboletas): poucos triângulos com a
// cor nos vértices. As asas BATEM aqui no vértice: as do lado +X e as do
// lado -X giram em volta do corpo (o eixo Z) — o voo (Temas._borboleta) só
// move a borboleta inteira. Cada uma bate no seu tempo: a fase sai da
// posição dela no mundo.

uniform float bater = 11.0;

varying float luz;

void vertex() {
	float lado = sign(VERTEX.x);
	float d = abs(VERTEX.x);
	float fase = dot(WORLD_MATRIX[3].xz, vec2(1.7, 2.3));
	float a = 0.2 + 1.05 * (0.5 + 0.5 * sin(TIME * bater + fase));
	VERTEX.x = lado * d * cos(a);
	VERTEX.y += d * sin(a);
	// a asa de pé pega menos luz que a aberta
	luz = 1.0 - 0.22 * a;
}

void fragment() {
	ALBEDO = COLOR.rgb * luz;
}
