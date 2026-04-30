/*
AAA Procedural Rain & Puddle Shader - Vector Stable Edition
Fixes the reflection "jerking" bug by correcting Normal Map vector spaces.
*/

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// ==========================================
// 1. BASE MATERIAL
// ==========================================
group_uniforms Base_Material;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal;
uniform sampler2D roughness_tex : hint_default_white;
uniform sampler2D height_tex : hint_default_black; 
uniform float uv_scale : hint_range(0.1, 20.0) = 1.0;

// ==========================================
// 2. WEATHER SYSTEM
// ==========================================
group_uniforms Weather_System;
uniform float rain_amount : hint_range(0.0, 1.0) = 1.0; 
uniform float wetness : hint_range(0.0, 1.0) = 0.5; 
uniform float puddle_darkening : hint_range(0.0, 1.0) = 0.6; 

// ==========================================
// 3. MACRO PUDDLES
// ==========================================
group_uniforms Macro_Puddles;
uniform sampler2D macro_noise_tex : hint_default_black; 
uniform float macro_noise_scale : hint_range(0.01, 1.0) = 0.1;
uniform float macro_noise_contrast : hint_range(0.0, 0.99) = 0.3; 
uniform float puddle_spread : hint_range(0.0, 1.0) = 0.3;
uniform float puddle_edge_softness : hint_range(0.001, 0.5) = 0.05;

// ==========================================
// 4. DROPS
// ==========================================
group_uniforms Drops;
uniform sampler2D drops_tex; 
uniform float drops_size : hint_range(0.1, 10.0) = 1.0;
uniform float drops_intensity : hint_range(0.0, 10.0) = 1.0; 
uniform float static_drops : hint_range(0.0, 1.0) = 0.0; 

// ==========================================
// 5. RIPPLES
// ==========================================
group_uniforms Ripples;
uniform sampler2D ripples_tex; 
uniform float ripples_scale : hint_range(0.01, 2.0) = 0.1;
uniform float ripples_intensity : hint_range(0.0, 2.0) = 1.0;

// ==========================================
// 6. PUDDLE WAVES
// ==========================================
group_uniforms Puddle_Waves;
uniform sampler2D wave_noise_tex : hint_normal; 
uniform float wave_scale : hint_range(0.1, 10.0) = 2.0;
uniform float wave_speed : hint_range(0.0, 1.0) = 0.1;
uniform float wave_strength : hint_range(0.0, 1.0) = 0.3;

varying vec3 v_world_pos;

void vertex() {
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// --- DROP MATH ---
vec4 get_drops(vec2 drops_uv, float time) {
    vec4 drops;
    vec4 drops_tex_color = textureLod(drops_tex, drops_uv * drops_size, 0.0);
    drops.xyz = vec3(drops_tex_color.rg, 1.0);
    float static_drops_mask = 1.0 - step(0.1, drops_tex_color.a);
    
    float animated_shift = drops_intensity * fract((drops_tex_color.b * 2.0 - 1.0) - time * 0.25);
    float time_shift = mix(animated_shift, drops_intensity, static_drops);
    
    float dyn_drops_mask = step(0.9, drops_tex_color.a) * time_shift;
    vec3 drops_dyn = mix(vec3(0.5, 0.5, 1.0), drops.xyz, time_shift);
    
    drops.a = dyn_drops_mask + static_drops_mask;
    drops.xyz = mix(vec3(0.5, 0.5, 1.0), drops.xyz, static_drops_mask);
    drops.xyz = mix(drops.xyz, drops_dyn, dyn_drops_mask);
    
    // BUGSQUASH: Removed normalizer here. Kept strictly in [0,1] color space.
    return drops;
}

// Creates a pseudo-random number based on a 2D coordinate
vec2 random_hash(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

// Calculates the physical height of the procedural ripples
float get_ripple_height(vec2 uv, float time, float scale) {
    vec2 grid_uv = uv * scale;
    vec2 grid_id = floor(grid_uv);
    vec2 grid_fract = fract(grid_uv);

    float ripple_height = 0.0;

    // Loop through the current cell and the 8 surrounding cells so ripples overlap
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 rand_point = random_hash(grid_id + neighbor);

            // Calculate distance to the random center point
            vec2 diff = neighbor + rand_point - grid_fract;
            float dist = length(diff);

            // Give each drop its own starting time based on its random X coordinate
            float drop_time = fract(time * 0.8 + rand_point.x);

            // The Magic: Subtracting time makes the ring expand OUTWARD
            float ring = sin(dist * 30.0 - drop_time * 20.0);

            // Fade the ring out at the cell edges, and as it gets older
            float fade = smoothstep(0.6, 0.0, dist) * smoothstep(1.0, 0.7, drop_time) * smoothstep(0.0, 0.1, drop_time);

            ripple_height += ring * fade;
        }
    }
    return ripple_height;
}

// --- RIPPLE MATH ---
// Converts the procedural height map into a stable normal map vector
vec4 get_ripples(vec2 uv, float time) {
    float epsilon = 0.01; // Distance to check for slope
    
    // Sample the center height, and the height slightly to the X and Y
    float h  = get_ripple_height(uv, time, ripples_scale * 10.0);
    float hx = get_ripple_height(uv + vec2(epsilon, 0.0), time, ripples_scale * 10.0);
    float hy = get_ripple_height(uv + vec2(0.0, epsilon), time, ripples_scale * 10.0);
    
    // Calculate the slope (normal) from the height differences
    vec3 normal = normalize(vec3(h - hx, h - hy, 0.5)); // 0.5 controls normal strength
    
    // Convert back to [0, 1] color space for Godot
    vec3 repacked_normal = normal * 0.5 + 0.5;
    
    // Return with a solid alpha
    return vec4(repacked_normal, 1.0);
}

// --- PUDDLE WAVES ---
vec3 get_puddle_waves(vec2 uv, float time) {
    vec2 wave_uv_1 = (uv * wave_scale) + vec2(time * wave_speed, time * wave_speed * 0.5);
    vec2 wave_uv_2 = (uv * wave_scale * 0.8) + vec2(-time * wave_speed * 0.7, time * wave_speed * 0.3);
    
    vec3 w1 = texture(wave_noise_tex, wave_uv_1).rgb;
    vec3 w2 = texture(wave_noise_tex, wave_uv_2).rgb;
    
    // BUGSQUASH: Safely unpack [0,1] colors to [-1,1] vectors before doing addition math
    vec3 n1 = w1 * 2.0 - 1.0;
    vec3 n2 = w2 * 2.0 - 1.0;
    
    vec3 final_wave = normalize(n1 + n2);
    
    // Repack back to [0,1] color space for Godot's NORMAL_MAP to process correctly
    vec3 repacked_wave = final_wave * 0.5 + 0.5;
    
    return mix(vec3(0.5, 0.5, 1.0), repacked_wave, wave_strength);
}

void fragment() {
    float time = TIME * 1.5;
    vec2 base_uv = UV * uv_scale;
    
    vec3 base_albedo = texture(albedo_tex, base_uv).rgb;
    vec3 base_normal = texture(normal_tex, base_uv).rgb;
    float base_roughness = texture(roughness_tex, base_uv).r;
    float surface_height = texture(height_tex, base_uv).r; 
    
    float raw_noise = texture(macro_noise_tex, v_world_pos.xz * macro_noise_scale).r;
    float macro_noise = smoothstep(macro_noise_contrast, 1.0, raw_noise);
    
    float water_level = wetness + (macro_noise * puddle_spread);
    float puddle_depth = water_level - surface_height;
    
    float puddle_mask = smoothstep(0.0, puddle_edge_softness, puddle_depth);
    puddle_mask *= step(0.01, wetness); 
    
    float damp_mask = smoothstep(0.0, 0.5, wetness); 
    
    vec3 base_water_normal = get_puddle_waves(base_uv, TIME); 
    vec3 water_surface_normal = base_water_normal; 
    vec3 drop_normal = vec3(0.5, 0.5, 1.0); 
    
    vec4 drops = get_drops(base_uv, time);
    drop_normal = drops.rgb;
    float drop_mask = drops.a * damp_mask * (1.0 - puddle_mask) * rain_amount; 
    
    vec4 ripples = get_ripples(base_uv, time);
    vec3 ripple_norm = mix(base_water_normal, ripples.rgb, ripples.a * ripples_intensity);
    water_surface_normal = mix(base_water_normal, ripple_norm, puddle_mask * rain_amount);
    
    vec3 final_albedo = base_albedo * (1.0 - (puddle_darkening * damp_mask));
    
    float final_roughness = mix(base_roughness, base_roughness * 0.4, damp_mask);
    final_roughness = mix(final_roughness, 0.07, drop_mask); 
    final_roughness = mix(final_roughness, mix(0.02, 0.08, wave_strength), puddle_mask); 
    
    vec3 final_normal = base_normal;
    final_normal = mix(final_normal, drop_normal, drop_mask);
    final_normal = mix(final_normal, water_surface_normal, puddle_mask);

    ALBEDO = final_albedo;
    ROUGHNESS = final_roughness;
    // Godot takes this NORMAL_MAP color and does the final internal unpack/normalize step safely!
    NORMAL_MAP = final_normal;
    SPECULAR = mix(0.5, 0.8, puddle_mask); 
}