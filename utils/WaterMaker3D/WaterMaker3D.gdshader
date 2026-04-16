shader_type spatial;
render_mode blend_mix, cull_disabled, specular_schlick_ggx;

// --- COLOR & DEPTH ---
uniform vec4 shallow_color : source_color = vec4(0.25, 0.45, 0.65, 1.0); 
uniform vec4 deep_color : source_color = vec4(0.0, 0.05, 0.15, 1.0);
uniform float depth_distance : hint_range(0.1, 50.0) = 4.0;
uniform float beers_law : hint_range(0.1, 20.0) = 2.5;

// --- UNDERWATER CONTROLS ---
uniform vec4 underwater_ceiling_color : source_color = vec4(0.0, 0.1, 0.2, 1.0);
uniform float underwater_ripple_strength : hint_range(0.0, 10.0) = 3.0;
uniform bool impenetrable = false; // Check this to completely block the sky

// --- REFRACTION & REFLECTION ---
uniform float refraction_strength : hint_range(0.0, 0.2) = 0.03;

// --- FOAM ---
uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform float foam_distance : hint_range(0.0, 2.0) = 0.3;

// --- SURFACE DETAILS (NORMAL MAPS) ---
uniform sampler2D normal_map_1;
uniform sampler2D normal_map_2;
uniform vec2 uv_scale = vec2(2.0, 2.0); 
uniform float normal_bump_strength : hint_range(0.1, 10.0) = 2.0; 
uniform vec2 pan_speed_1 = vec2(0.02, 0.01);
uniform vec2 pan_speed_2 = vec2(-0.015, 0.025);

// --- WAVES ---
uniform float wave_amplitude = 0.15;
uniform float wave_frequency = 1.5;
uniform float wave_speed = 1.5;

// --- SCREEN READERS ---
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

varying vec3 local_normal;

void vertex() {
    local_normal = NORMAL;
    
    if (NORMAL.y > 0.5) {
        float time = TIME * wave_speed;
        float h1 = sin(VERTEX.x * wave_frequency + time) * wave_amplitude;
        float h2 = sin((VERTEX.x * 0.8 + VERTEX.z * 0.6) * (wave_frequency * 1.5) - time * 1.2) * (wave_amplitude * 0.6);
        float h3 = cos((VERTEX.z * 1.2 - VERTEX.x * 0.3) * (wave_frequency * 0.8) + time * 0.7) * (wave_amplitude * 0.4);
        VERTEX.y += h1 + h2 + h3;
    }
}

void fragment() {
    vec2 uv_1 = UV * uv_scale + TIME * pan_speed_1;
    vec2 uv_2 = UV * uv_scale + TIME * pan_speed_2;
    
    vec3 n1 = texture(normal_map_1, uv_1).rgb * 2.0 - 1.0;
    vec3 n2 = texture(normal_map_2, uv_2).rgb * 2.0 - 1.0;
    vec3 combined_normal = normalize(n1 + n2);
    
    combined_normal.xy *= normal_bump_strength;
    vec3 final_normal_dir = normalize(combined_normal);

    bool is_underwater = !FRONT_FACING;

    if (is_underwater) {
        // ==========================================
        // VIEW FROM BELOW (Swimming underwater)
        // ==========================================
        
        if (local_normal.y < 0.5) {
            discard; 
        }

        float view_angle = abs(dot(NORMAL, VIEW));
        float snells_window = smoothstep(0.05, 0.5, view_angle - (final_normal_dir.x * 0.15));

        if (impenetrable) {
            // IMPENETRABLE MODE: Skip all screen reading. Just draw a solid, rippling ceiling.
            ALBEDO = underwater_ceiling_color.rgb;
            
            // Apply bright caustic peaks using the new ripple strength slider
            ALBEDO += max(vec3(0.0), (final_normal_dir - 0.5) * underwater_ripple_strength * 0.2);
            
        } else {
            // HL2 MODE: Warp the sky and mix it with the ceiling color
            vec2 ref_ofs = final_normal_dir.xy * refraction_strength * underwater_ripple_strength * snells_window;
            
            float r = texture(SCREEN_TEXTURE, clamp(SCREEN_UV + ref_ofs * 1.15, 0.001, 0.999)).r;
            float g = texture(SCREEN_TEXTURE, clamp(SCREEN_UV + ref_ofs, 0.001, 0.999)).g;
            float b = texture(SCREEN_TEXTURE, clamp(SCREEN_UV + ref_ofs * 0.85, 0.001, 0.999)).b;
            vec3 heavily_warped_sky = vec3(r, g, b);

            ALBEDO = mix(underwater_ceiling_color.rgb, heavily_warped_sky, snells_window);
            ALBEDO += max(vec3(0.0), (final_normal_dir - 0.5) * underwater_ripple_strength * 0.2) * snells_window;
        }

        ALPHA = 1.0; 
        SPECULAR = 0.0;
        ROUGHNESS = 0.5;

    } else {
        // ==========================================
        // VIEW FROM ABOVE (Standing on the shore)
        // ==========================================
        
        NORMAL_MAP = final_normal_dir * 0.5 + 0.5;

        float depth_raw = textureLod(DEPTH_TEXTURE, SCREEN_UV, 0.0).r;
        vec4 world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
        world_pos.xyz /= world_pos.w;
        float depth_z = -world_pos.z; 
        float vertex_z = -VERTEX.z; 
        float water_depth = max(0.0, depth_z - vertex_z);

        float depth_exp = exp(-water_depth / depth_distance);
        float beers_blend = pow(depth_exp, beers_law);

        vec2 ref_ofs = final_normal_dir.xy * refraction_strength * depth_exp; 
        vec2 safe_uv = clamp(SCREEN_UV + ref_ofs, vec2(0.001), vec2(0.999));

        vec3 refracted_bg = texture(SCREEN_TEXTURE, safe_uv).rgb;

        vec3 water_color = mix(deep_color.rgb, shallow_color.rgb, beers_blend);
        vec3 surface_albedo = mix(water_color, refracted_bg, depth_exp);

        float foam_mask = 1.0 - smoothstep(0.0, foam_distance, water_depth);
        float foam_noise = texture(normal_map_1, UV * uv_scale * 2.0 + TIME * 0.05).r;
        foam_mask *= step(0.4, foam_noise + foam_mask * 0.8);
        
        ALBEDO = mix(surface_albedo, foam_color.rgb, foam_mask);
        ROUGHNESS = mix(0.02, 0.4, foam_mask);
        SPECULAR = mix(0.5, 0.0, foam_mask);
        ALPHA = clamp(water_depth * 20.0, 0.0, 1.0); 
    }
}