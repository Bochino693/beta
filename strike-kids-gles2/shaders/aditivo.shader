shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

// Brilhos, chamas dos jatos, faíscas: soma luz.

uniform sampler2D textura : hint_albedo;
uniform vec4 cor : hint_color = vec4(1.0);
uniform float forca = 1.0;

void fragment() {
	vec4 t = texture(textura, UV);
	vec4 c = t * cor * COLOR;
	ALBEDO = c.rgb * c.a * forca;
	ALPHA = 1.0;
}
