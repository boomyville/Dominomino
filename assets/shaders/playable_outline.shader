shader_type canvas_item;

uniform vec4 outline_color : hint_color = vec4(0.0, 1.0, 0.0, 1.0); // Green
uniform float is_active = 0.0; // 0.0 = Hidden, 1.0 = Visible

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	
	// Only calculate adjacent borders if the active flag float is greater than 0.5
	if (is_active > 0.5) {
		vec2 size = TEXTURE_PIXEL_SIZE;
		float alpha = texture(TEXTURE, UV + vec2(0.0, -size.y)).a;
		alpha += texture(TEXTURE, UV + vec2(0.0, size.y)).a;
		alpha += texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;
		alpha += texture(TEXTURE, UV + vec2(size.x, 0.0)).a;
		
		if (col.a == 0.0 && alpha > 0.0) {
			col = outline_color;
		}
	}
	COLOR = col;
}