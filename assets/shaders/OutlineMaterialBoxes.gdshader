shader_type spatial;
// unshaded: IGNORES ALL LIGHTS (Sun, Lamps, etc.)
// blend_add: Makes it "glow" on top of the original texture
// depth_test_disabled: (Optional) if you want to see it through walls
render_mode unshaded, blend_add, depth_draw_opaque;

uniform vec4 highlight_color : source_color = vec4(0.0, 1.0, 0.5, 1.0);
uniform float blink_speed : hint_range(0.0, 20.0) = 4.0; 
uniform float min_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float max_intensity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    // Create the pulsing wave (0.0 to 1.0)
    float pulse = (sin(TIME * blink_speed) + 1.0) / 2.0;
    
    // Calculate how much "highlight" to apply
    float current_intensity = mix(min_intensity, max_intensity, pulse);
    
    // Set the color. Since it's 'unshaded', this is exactly what you'll see.
    ALBEDO = highlight_color.rgb;
    
    // Use Alpha to control the strength of the highlight
    ALPHA = highlight_color.a * current_intensity;
}