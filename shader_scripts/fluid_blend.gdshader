// fluid_blend.gdshader
shader_type canvas_item;

// This shader applies a screen-space metaball threshold effect
// to blend overlapping particles rendered into a separate viewport/texture.

// The particle texture containing the rendered particles (usually a SubViewport)
uniform sampler2D fluid_texture : filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec4 fluid_color : source_color = vec4(0.2, 0.5, 0.9, 1.0);
uniform float threshold : hint_range(0.0, 1.0) = 0.5;
uniform float softness : hint_range(0.0, 0.2) = 0.05;

void fragment() {
	// Sample the fluid texture (which has blurred particles)
	vec4 fluid_sample = texture(fluid_texture, UV);
	float alpha = fluid_sample.a;

	// Apply threshold to create a sharp edge for metaball effect
	float smooth_alpha = smoothstep(threshold - softness, threshold + softness, alpha);

	// Since we are rendering via CanvasLayer over everything, we should ideally use depth testing.
	// We read the 3D scene depth texture.
	// Since canvas_item shaders don't directly have hint_depth_texture from 3D without setup,
	// if depth texture is provided by the main camera viewport, we can check it.
	// For a 2D canvas item overlay, this allows discarding fluid pixels that should be behind 3D objects.

	// Note: In Godot 4, to read the 3D depth texture in a canvas_item shader,
	// the camera must have depth_texture enabled, and the shader must use a `hint_depth_texture` sampler
	// bound to the SCREEN_TEXTURE or passed manually. This is advanced, so we'll provide the placeholder
	// logic, but if no depth is passed, it won't clip.
	// A complete 3D integration would instead render the fluid on a MeshInstance3D in front of the camera,
	// or use a quad that reads the depth.

	// Simple normal calculation based on alpha gradient
	vec2 pixel_size = 1.0 / vec2(textureSize(fluid_texture, 0));

	float alpha_dx = texture(fluid_texture, UV + vec2(pixel_size.x, 0.0)).a - texture(fluid_texture, UV - vec2(pixel_size.x, 0.0)).a;
	float alpha_dy = texture(fluid_texture, UV + vec2(0.0, pixel_size.y)).a - texture(fluid_texture, UV - vec2(0.0, pixel_size.y)).a;

	vec3 normal = normalize(vec3(-alpha_dx * 10.0, -alpha_dy * 10.0, 1.0));

	// Fake specular highlight
	vec3 light_dir = normalize(vec3(1.0, 1.0, 1.0));
	vec3 view_dir = vec3(0.0, 0.0, 1.0);
	vec3 half_vector = normalize(light_dir + view_dir);
	float specular = pow(max(dot(normal, half_vector), 0.0), 32.0);

	vec3 final_color = fluid_color.rgb + vec3(specular) * 0.5;

	COLOR = vec4(final_color, smooth_alpha);
}
