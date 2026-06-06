shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0); // Black by default
uniform float outline_width : hint_range(0.0, 5.0) = 1.0; // Thickness

void fragment() {
    // Get the size of a single pixel based on the texture resolution
    vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
    
    // Get the original color and alpha of your white circle
    vec4 sprite_color = texture(TEXTURE, UV);
    
    // Check the alpha of the pixels surrounding the current pixel (8 directions)
    float outline = texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;
    outline += texture(TEXTURE, UV + vec2(0.0, size.y)).a;
    outline += texture(TEXTURE, UV + vec2(size.x, 0.0)).a;
    outline += texture(TEXTURE, UV + vec2(0.0, -size.y)).a;
    outline += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
    outline += texture(TEXTURE, UV + vec2(size.x, size.y)).a;
    outline += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
    outline += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;
    
    // Clamp the outline value so it doesn't exceed 1.0
    outline = min(outline, 1.0);
    
    // Mix the black outline with your white circle based on the circle's original alpha
    vec4 final_color = mix(outline_color, sprite_color, sprite_color.a);
    
    // Output the final color, combining the circle's alpha and the new outline's alpha
    COLOR = vec4(final_color.rgb, max(sprite_color.a, outline));
}