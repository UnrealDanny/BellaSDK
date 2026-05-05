shader_type canvas_item;

uniform float blur_size : hint_range(0.0, 10.0) = 4.0;
uniform float pan_amount : hint_range(0.0, 0.1) = 0.05; // How far it moves (5%)
uniform float pan_speed : hint_range(0.0, 5.0) = 1.0;   // How fast it moves

void fragment() {
    // 1. Calculate a smooth back-and-forth wave using TIME (-1.0 to 1.0)
    float wave = sin(TIME * pan_speed);
    
    // 2. Zoom the UVs in slightly (by 10%) so we have room to pan without exposing the edges
    vec2 zoom_uv = (UV - 0.5) * 0.9 + 0.5; 
    
    // 3. Add the horizontal panning offset
    vec2 panned_uv = zoom_uv + vec2(wave * pan_amount, 0.0);

    // 4. Perform the 9-tap blur using our new zoomed and panned coordinates
    vec2 pixel = TEXTURE_PIXEL_SIZE;
    vec4 color = vec4(0.0);
    
    color += texture(TEXTURE, panned_uv + vec2(-pixel.x, -pixel.y) * blur_size);
    color += texture(TEXTURE, panned_uv + vec2(0.0, -pixel.y) * blur_size);
    color += texture(TEXTURE, panned_uv + vec2(pixel.x, -pixel.y) * blur_size);
    color += texture(TEXTURE, panned_uv + vec2(-pixel.x, 0.0) * blur_size);
    color += texture(TEXTURE, panned_uv) * 2.0; // Center pixel gets slightly more weight
    color += texture(TEXTURE, panned_uv + vec2(pixel.x, 0.0) * blur_size);
    color += texture(TEXTURE, panned_uv + vec2(-pixel.x, pixel.y) * blur_size);
    color += texture(TEXTURE, panned_uv + vec2(0.0, pixel.y) * blur_size);
    color += texture(TEXTURE, panned_uv + vec2(pixel.x, pixel.y) * blur_size);
    
    // Output the final blurred, moving color
    COLOR = color / 10.0;
}