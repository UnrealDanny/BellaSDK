shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.12, 0.12, 0.12, 1.0);

// --- ONLY 2 SHADOW POSITIONS NOW ---
uniform float shadow_1_x = -0.5; 
uniform float shadow_2_x = 1.5;  

// NEW: Control the speed of the automatic, independent scrolling
uniform float speed = 0.5;

uniform float shadow_width : hint_range(0.0, 1.0) = 0.28; 
uniform float softness : hint_range(0.0, 1.0) = 0.1; 
uniform float tilt : hint_range(-1.0, 1.0) = 0.3; 

uniform float hover_intensity : hint_range(0.0, 1.0) = 0.0; 
uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.4, 1.0); 
uniform float glow_strength : hint_range(0.0, 10.0) = 4.0; 

void fragment() {
    vec4 text_col = texture(TEXTURE, UV);
    
    // Protect the outline
    float luma = dot(text_col.rgb, vec3(0.299, 0.587, 0.114));
    float fill_mask = smoothstep(0.6, 0.9, luma);
    
    // Slanted X position
    float slanted_x = UV.x + (UV.y - 0.5) * tilt;
    
    // NEW: We use TIME * speed to make the position move independently of your script.
    // The mod() function wraps the space perfectly between your -0.5 and 1.5 shadow bounds,
    // creating an infinite, seamless loop.
    float animated_x = mod(slanted_x - (TIME * speed) + 0.5, 2.0) - 0.5;
    
    // Distance math for 2 shadows using the new animated X
    float dist1 = abs(animated_x - shadow_1_x);
    float dist2 = abs(animated_x - shadow_2_x);
    
    float dist = min(dist1, dist2);
    
    // Core masks
    float mask = smoothstep(shadow_width, shadow_width - softness, dist);
    
    // NEW: Fade out the shadow completely as hover_intensity approaches 1.0.
    // This ensures the original text becomes fully clear and readable on hover.
    mask *= (1.0 - hover_intensity);
    
    float edge_width = softness * 1.5;
    float edge_mask = smoothstep(shadow_width + edge_width, shadow_width, dist) 
                    - smoothstep(shadow_width, shadow_width - edge_width, dist);
    
    // Apply math strictly multiplied by the strict fill_mask
    vec3 final_rgb = mix(text_col.rgb, shadow_color.rgb, mask * fill_mask);
    vec3 sun_flare = (glow_color.rgb * glow_strength) * edge_mask * hover_intensity * fill_mask;
    final_rgb += sun_flare;
    vec3 global_warmth = (glow_color.rgb * 0.4) * hover_intensity * (1.0 - mask) * fill_mask;
    final_rgb += global_warmth;
    
    COLOR = vec4(final_rgb, text_col.a);
}