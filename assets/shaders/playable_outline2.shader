shader_type canvas_item;

uniform vec4 outline_color : hint_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform float is_active = 0.0;
uniform float speed : hint_range(0.1, 10.0) = 3.0;
uniform float snake_len : hint_range(0.1, 1.0) = 0.4;
uniform vec2 object_scale = vec2(1.0, 1.0);

// New uniform to track rotation adjustments
uniform float parent_rotation = 0.0; 

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    
    if (is_active > 0.5) {
        vec2 size = TEXTURE_PIXEL_SIZE;
        float alpha = texture(TEXTURE, UV + vec2(0.0, -size.y)).a;
        alpha += texture(TEXTURE, UV + vec2(0.0, size.y)).a;
        alpha += texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;
        alpha += texture(TEXTURE, UV + vec2(size.x, 0.0)).a;
        
        if (col.a == 0.0 && alpha > 0.0) {
            vec2 unified_coord = (UV - vec2(0.5)) * object_scale;
            
            // Calculate baseline angle
            float angle = (atan(unified_coord.y, unified_coord.x) + 3.14159265) / (2.0 * 3.14159265);
            
            // Offset the angle by the parent tile rotation step (converted to a 0.0 -> 1.0 range)
            float adjusted_angle = fract(angle + (parent_rotation / 360.0));
            
            float snake_progress = fract((adjusted_angle - TIME * speed * 0.05) * 2.0);
            
            if (snake_progress < snake_len) {
                float half_len = snake_len * 0.5;
                float intensity = 1.0;
                
                if (snake_progress > half_len) {
                    intensity = 1.0 - ((snake_progress - half_len) / half_len);
                }
                
                col = vec4(outline_color.rgb, outline_color.a * intensity);
            } else {
                col = vec4(0.0);
            }
        }
    }
    COLOR = col;
}