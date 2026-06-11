shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

// Reads the exact distance injected by your stationary laser script
instance uniform float segment_length = 1.0;

uniform vec4 beam_color : source_color = vec4(0.1, 0.6, 1.0, 1.0);
uniform vec4 sparkle_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Beam visual settings
uniform float emission_strength = 3.0;
uniform float core_thickness : hint_range(0.0, 1.0) = 0.2;

// Sparkle settings
uniform sampler2D noise_texture : repeat_enable, filter_linear;
uniform float sparkle_density : hint_range(0.0, 1.0) = 0.85; 
uniform float sparkle_speed = 3.0;
uniform float sparkle_scale = 5.0;

void fragment() {
    // 1. Correct UV Stretching
    // Multiply the vertical UV by the physical length of the segment.
    // This perfectly tiles the noise texture so sparkles remain round.
    vec2 base_uv = UV;
    base_uv.y *= max(segment_length, 1.0); 
    
    // 2. Base Beam Core Gradient
    // UV.x maps from 0.0 to 1.0 across the width of the cylinder mesh
    float dist_from_center = abs(UV.x - 0.5) * 2.0; 
    float core_glow = 1.0 - smoothstep(core_thickness, 1.0, dist_from_center);
    
    // 3. Sparkle Generation via Panning Noise
    vec2 noise_uv = base_uv * vec2(1.0, sparkle_scale);
    noise_uv.y -= TIME * sparkle_speed; 
    
    float noise_val = texture(noise_texture, noise_uv).r;
    
    // Isolate the highest peaks of the noise texture to create individual dots
    float sparkles = smoothstep(sparkle_density, sparkle_density + 0.05, noise_val);
    
    // Twinkle effect: oscillate the opacity based on time and restrict to the beam bounds
    sparkles *= (sin(TIME * 20.0 + noise_val * 10.0) * 0.5 + 0.5);
    sparkles *= 1.0 - smoothstep(0.7, 1.0, dist_from_center);
    
    // 4. Blend Colors & Alpha
    vec3 final_albedo = beam_color.rgb * core_glow;
    final_albedo += sparkle_color.rgb * sparkles;
    
    ALBEDO = final_albedo;
    
    // Boost emission so it blooms heavily with a WorldEnvironment Glow
    EMISSION = final_albedo * emission_strength;
    
    ALPHA = clamp(core_glow + sparkles, 0.0, 1.0) * beam_color.a;
}