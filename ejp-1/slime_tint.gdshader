shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// luminancia (0 = negro, 1 = blanco)
	float l = dot(tex.rgb, vec3(0.299, 0.587, 0.114));

	// mezcla entre blanco y el color, pero respetando la luz
	vec3 colored = mix(vec3(0.0), tint_color.rgb, l);

	// reintroduce el blanco real
	colored = mix(colored, vec3(1.0), l);

	COLOR = vec4(colored, tex.a);
}