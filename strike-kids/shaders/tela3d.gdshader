shader_type canvas_item;

// A IMAGEM 3D NA TELA: esticada até a tela inteira (a imagem 3D é desenhada
// menor) e, de quebra, o ajuste de cor (mais vivo e com um pouco mais de
// contraste) — de graça, na mesma passada que já existe. Sem o pós-
// processamento do motor (que custaria uma imagem inteira a mais).

uniform float saturacao = 1.12;
uniform float contraste = 1.04;

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturacao);
	c = (c - 0.5) * contraste + 0.5;
	COLOR = vec4(c, 1.0);
}
