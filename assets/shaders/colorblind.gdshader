shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// 0: Off
// 1: Protanopia (Red-blind)
// 2: Deuteranopia (Green-blind)
// 3: Tritanopia (Blue-blind)
// 4: Achromatopsia (Monochrome)
uniform int mode = 0; 

void fragment() {
    vec3 c = texture(screen_texture, SCREEN_UV).rgb;
    
    // Protanopia
    if (mode == 1) { 
        c = vec3(c.r * 0.56667 + c.g * 0.43333, c.r * 0.55833 + c.g * 0.44167, c.b);
    } 
    // Deuteranopia
    else if (mode == 2) { 
        c = vec3(c.r * 0.625 + c.g * 0.375, c.r * 0.7 + c.g * 0.3, c.b);
    } 
    // Tritanopia
    else if (mode == 3) { 
        c = vec3(c.r * 0.95 + c.g * 0.05, c.g * 0.43333 + c.b * 0.56667, c.g * 0.475 + c.b * 0.525);
    } 
    // Achromatopsia
    else if (mode == 4) { 
        float gray = dot(c, vec3(0.299, 0.587, 0.114));
        c = vec3(gray);
    }
    
    COLOR = vec4(c, 1.0);
}
