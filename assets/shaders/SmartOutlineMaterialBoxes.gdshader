shader_type spatial;
// blend_mix: Allows for standard transparency (opacity)
// depth_draw_opaque: Prevents transparent sorting issues
render_mode blend_mix, depth_draw_opaque;

uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float glow_strength : hint_range(0.0, 10.0) = 2.0;

// NEW: Blinking Controls
uniform float blink_speed : hint_range(0.0, 20.0) = 15.0; 
uniform float min_opacity : hint_range(0.0, 1.0) = 0.1; // The dimmest it gets
uniform float max_opacity : hint_range(0.0, 1.0) = 2; // The brightest it gets

void fragment() {
    // 1. Create the Blink Math
    // sin(TIME * speed) outputs a wave from -1.0 to 1.0. 
    // We add 1.0 to make it 0.0 to 2.0, then divide by 2 to make it a perfect 0.0 to 1.0 scale.
    float pulse = (sin(TIME * blink_speed) + 1.0) / 2.0;
    
    // 2. Mix the min and max opacity based on where the wave currently is
    float current_alpha = mix(min_opacity, max_opacity, pulse);
    
    // 3. Set the base color
    ALBEDO = highlight_color.rgb;
    
    // 4. Apply our new pulsing alpha
    ALPHA = current_alpha;
    
    // 5. Multiply the emission by the pulse so the glow physically dims and brightens too
    EMISSION = highlight_color.rgb * glow_strength * pulse;
}



//shader_type spatial;
//// unshaded: ignores lighting
//// cull_front: draws inside-out
//render_mode unshaded, cull_front;
//
//uniform float outline_thickness = 0.005; 
////uniform float camera_pull = 0.06; // NEW: Pulls the outline forward
//uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
//
//void vertex() {
    //// 1. Convert the vertex position to Clip Space (Screen space)
    //vec4 clip_position = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
    //
    //// 2. Convert the Normal (direction the face points) to Clip Space
    //// We only need the X and Y (screen horizontal and vertical)
    //vec3 clip_normal = mat3(PROJECTION_MATRIX) * (mat3(MODELVIEW_MATRIX) * NORMAL);
    //
    //// 3. Offset the position based on the normal and the thickness
    //// We divide by 'clip_position.w' to keep the line size constant regardless of distance
    //vec2 offset = normalize(clip_normal.xy) * outline_thickness * clip_position.w;
    //
    //// 4. Apply the offset to the screen position
    //clip_position.xy += offset;
    //
    //// 5. Set the final position
	////clip_position.z -= 0.001 * clip_position.w;
    //POSITION = clip_position;
//}
//
//void fragment() {
    //// Read the screen behind the pixel
    //vec4 screen_color = texture(screen_texture, SCREEN_UV);
    //
    //// Calculate brightness
    //float brightness = dot(screen_color.rgb, vec3(0.299, 0.587, 0.114));
    //
    //// Smart contrast: Black if bright background, White if dark background
    //ALBEDO = mix(vec3(1.0), vec3(0.0), step(0.5, brightness));
//}