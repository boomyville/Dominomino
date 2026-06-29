void fragment() {
    vec4 col = texture(TEXTURE, UV);
    
    if (is_active > 0.5) {
        if (col.a > 0.0) {
            col = outline_color;
        }
    } else {
        col = vec4(0.0);
    }
    
    // Always discard the base fill, only keep outline pixels
    COLOR = col;
}