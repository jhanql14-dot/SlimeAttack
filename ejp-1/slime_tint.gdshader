shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	
	// Si es el ojo (negro casi puro), no lo pintamos
	if (tex.r < 0.1 && tex.g < 0.1 && tex.b < 0.1) {
		COLOR = tex;
	} else {
		// Aplicar el color con alta saturación
		// Usamos el tinte directamente pero conservamos los brillos (highlights)
		vec3 colored = tex.rgb * tint_color.rgb;
		
		// Aumentar el contraste y la saturación
		colored = mix(colored, tint_color.rgb, 0.3);
		
		// Reintroducir brillos blancos
		float brightness = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		if (brightness > 0.8) {
			colored = mix(colored, vec3(1.0), (brightness - 0.8) * 5.0);
		}
		
		COLOR = vec4(colored, tex.a);
	}
}