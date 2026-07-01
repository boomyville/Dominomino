void fragment() {
    vec4 col = texture(TEXTURE, UV);
    if (is_active > 0.5) {
        col = vec4(1.0, 1.0, 0.0, 1.0);  // paint EVERYTHING yellow
    } else {
        col = vec4(0.0);
    }
    COLOR = col;
}