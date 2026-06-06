shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.12, 0.12, 0.12, 1.0);

// --- ONLY 2 SHADOW POSITIONS NOW ---
uniform float shadow_1_x = -0.5; 
uniform float shadow_2_x = 1.5;  

// --- ANIMATION & SHADOW PARAMS ---
uniform float speed = 0.5;
uniform float shadow_width : hint_range(0.0, 1.0) = 0.28; 
uniform float softness : hint_range(0.0, 1.0) = 0.1; 
uniform float shadow_slant : hint_range(-1.0, 1.0) = 0.3; 

// --- GOLD HOVER PARAMS ---
uniform float hover_intensity : hint_range(0.0, 1.0) = 0.0; 
uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.4, 1.0); // True Gold

// --- 3D PERSPECTIVE PARAMS ---
uniform vec2 rect_size;
uniform vec2 ui_tilt; 
uniform float perspective_strength : hint_range(0.0, 0.5) = 0.15; 

void vertex() {
    // Prevent division by zero
    vec2 safe_rect = max(rect_size, vec2(1.0)); 
    vec2 pivot = safe_rect / 2.0;
    vec2 offset = VERTEX - pivot;

    // Calculate 3D depth push
    float depth = (offset.x / pivot.x) * ui_tilt.x + (offset.y / pivot.y) * ui_tilt.y;
    float perspective = 1.0 - (depth * perspective_strength);
    
    VERTEX = pivot + (offset * perspective);
}

void fragment() {
    vec4 text_col = texture(TEXTURE, UV);
    float text_alpha = text_col.a; // Use exact transparency, perfectly preserving font edges
    
    // --- SHADOW AI LOGIC ---
    // Protect the inner fill for shadows
    float luma = dot(text_col.rgb, vec3(0.299, 0.587, 0.114));
    float fill_mask = smoothstep(0.6, 0.9, luma);
    
    float slanted_x = UV.x + (UV.y - 0.5) * shadow_slant;
    float animated_x = mod(slanted_x - (TIME * speed) + 0.5, 2.0) - 0.5;
    
    float dist1 = abs(animated_x - shadow_1_x);
    float dist2 = abs(animated_x - shadow_2_x);
    float dist = min(dist1, dist2);
    
    float shadow_mask = smoothstep(shadow_width, shadow_width - softness, dist);
    shadow_mask *= (1.0 - hover_intensity); // Fade shadows away completely on hover
    
    // --- COMPOSITING ---
    // 1. Text smoothly turns to solid gold on hover
    vec3 base_rgb = mix(text_col.rgb, glow_color.rgb, hover_intensity);
    
    // 2. Apply the dark wandering shadows to the text (only visible when not hovered)
    vec3 final_rgb = mix(base_rgb, shadow_color.rgb, shadow_mask * fill_mask);
    
    // Output final color using the pure, unmodified alpha of the font
    COLOR = vec4(final_rgb, text_alpha);
}