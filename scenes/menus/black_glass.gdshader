shader_type canvas_item;

uniform vec2 rect_size;
uniform vec2 ui_tilt; 
uniform float perspective_strength : hint_range(0.0, 0.5) = 0.15; 

uniform float sweep_progress = -0.5; 
uniform float hover_intensity : hint_range(0.0, 1.0) = 0.0; 
uniform float angle : hint_range(0.0, 360.0) = 25.0;

uniform vec4 base_color : source_color = vec4(0.0, 0.0, 0.0, 1.0); 
uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 0.6);
uniform float shine_width : hint_range(0.01, 1.0) = 0.15; 
uniform float slab_opacity : hint_range(0.0, 1.0) = 0.95; 

uniform sampler2D blood_texture : repeat_enable; 
uniform vec2 mouse_pos_uv; 
uniform float reveal_radius : hint_range(0.0, 3.0) = 0.15; 
uniform float reveal_softness : hint_range(0.0, 1.0) = 0.1; 
uniform vec2 blood_offset = vec2(0.0, 0.0); 
uniform float blood_scale = 1.0; 

void vertex() {
    vec2 safe_rect = max(rect_size, vec2(1.0)); 
    vec2 pivot = safe_rect / 2.0;
    vec2 offset = VERTEX - pivot;

    float depth = (offset.x / pivot.x) * ui_tilt.x + (offset.y / pivot.y) * ui_tilt.y;
    float perspective = 1.0 - (depth * perspective_strength);
    
    VERTEX = pivot + (offset * perspective);
}

void fragment() {
    float bevel = (1.0 - UV.y) * 0.01 + (1.0 - UV.x) * 0.01;
    vec3 solid_black_result = base_color.rgb + vec3(bevel);

    float rad = radians(angle);
    vec2 dir = vec2(cos(rad), sin(rad));
    
    float dist = abs(dot(UV, dir) - sweep_progress);
    float entrance_shine = smoothstep(shine_width, 0.0, dist);

    vec2 centered_mouse = clamp(mouse_pos_uv - vec2(0.5), -0.5, 0.5);
    float glare_pos = 0.5 - (centered_mouse.x * cos(rad) + centered_mouse.y * sin(rad)) * 0.8; 
    float persistent_glare = smoothstep(0.4, 0.0, abs(dot(UV, dir) - glare_pos)) * 0.25 * hover_intensity;

    float total_shine = clamp((entrance_shine * hover_intensity) + persistent_glare, 0.0, 1.0);
    solid_black_result = mix(solid_black_result, shine_color.rgb, total_shine * shine_color.a);

    vec2 px_coords = UV * rect_size;
    float dist_x = min(px_coords.x, rect_size.x - px_coords.x);
    float dist_y = min(px_coords.y, rect_size.y - px_coords.y);
    float outer_mask = smoothstep(0.0, 1.0, min(dist_x, dist_y));

    // --- FIX 2: 3D MOUSE TRACKING ALIGNMENT ---
    // Calculate where this pixel visually sits after the 3D vertex tilt
    vec2 uv_offset = UV - vec2(0.5);
    float pixel_depth = (uv_offset.x / 0.5) * ui_tilt.x + (uv_offset.y / 0.5) * ui_tilt.y;
    float pixel_perspective = 1.0 - (pixel_depth * perspective_strength);
    vec2 visual_uv = vec2(0.5) + (uv_offset * pixel_perspective);

    float aspect = rect_size.x / rect_size.y;
    
    // We now use the visually-shifted UV to calculate the distance to the mouse
    vec2 aspect_uv = visual_uv; 
    aspect_uv.x *= aspect; 
    
    vec2 aspect_mouse = mouse_pos_uv;
    aspect_mouse.x *= aspect;
    
    float d = distance(aspect_uv, aspect_mouse);
    float reveal_mask = smoothstep(reveal_radius, reveal_radius - reveal_softness, d) * hover_intensity;
    // ------------------------------------------
    
    vec4 blood_col = texture(blood_texture, (aspect_uv * blood_scale) + blood_offset);
    vec3 facade_result = mix(solid_black_result, blood_col.rgb, reveal_mask);

    COLOR = vec4(facade_result, base_color.a * slab_opacity * outer_mask);
}