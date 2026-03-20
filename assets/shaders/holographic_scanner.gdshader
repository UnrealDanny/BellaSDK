shader_type spatial;
// blend_add makes it a transparent hologram. cull_disabled renders the inside of the tube.
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

// Expose colors to the inspector (source_color gives you a color picker)
instance uniform vec4 base_color : source_color = vec4(0.0, 0.2, 0.8, 0.1);
instance uniform vec4 line_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);

instance uniform float speed = 1.0;                 
instance uniform float line_count = 2.0;            
instance uniform float line_thickness : hint_range(0.01, 1.0) = 0.1;
instance uniform float glow_multiplier = 2.0;

void fragment() {
    // 1. Calculate the moving phase along the vertical axis (UV.y)
    float moving_uv = (UV.y * line_count) + (TIME * speed);

    // 2. Loop the value between 0.0 and 1.0 to create repeating sections
    float gradient = fract(moving_uv);

    // 3. Shape the gradient into a triangle wave that peaks exactly in the middle (0.5)
    float distance_to_center = abs(gradient - 0.5) * 2.0;
    float peak = 1.0 - distance_to_center;

    // 4. "Pinch" the peak based on your thickness slider to create a sharp or soft line
    float sharpness = 10.0 / line_thickness;
    float line_mask = pow(peak, sharpness);

    // 5. Apply the colors
    ALBEDO = mix(base_color.rgb, line_color.rgb, line_mask);
    ALPHA = mix(base_color.a, line_color.a, line_mask);

    // 6. Feed the line mask into the Emission channel so Godot's Glow effect picks it up
    EMISSION = line_color.rgb * line_mask * glow_multiplier;
}