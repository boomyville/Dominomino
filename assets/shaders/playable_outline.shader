shader_type canvas_item;

uniform vec4 outline_color : hint_color = vec4(0.0, 1.0, 0.0, 1.0); // Green
uniform float is_active = 0.0; // 0.0 = Hidden, 1.0 = Visible

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    
    if (is_active > 0.5) {
        // If the outline texture has a visible pixel, paint it your solid green color
        if (col.a > 0.0) {
            col = outline_color;
        }
    } else {
        // If the outline isn't active, make the whole texture transparent (hidden)
        col = vec4(0.0);
    }
    
    COLOR = col;
}