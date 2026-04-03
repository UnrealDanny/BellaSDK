shader_type spatial;
render_mode cull_disabled;

uniform float scale = 5;
uniform float speed = 2;
uniform float wiggle = 10;

uniform float drop_strength = 20;
uniform float trail_strength = 0.3;
uniform float refraction = .3;
uniform float blur = 3;
uniform float fade_distance = 5;
uniform int layers = 1;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap; 

float RandomNumber(vec2 seed){
	seed = fract(seed * vec2(123.456, 234.789));
	seed += dot(seed, seed * 34.73);
	return fract(seed.x * seed.y);
}

vec2 RainDrops(vec2 uv, float drop_scale, float drop_speed, float drop_wiggle) {
	float t = TIME * drop_speed;
	float by = (1. - uv.y) * .3 + .7;
	float w = uv.y * drop_wiggle;
	uv *= drop_scale;
	uv.y -= t * .25;
	vec2 grid_uv = fract(uv) - .5; 
	vec2 id = floor(uv);
	
	float rn = RandomNumber(id);
	t += rn * TAU;
	w *= rn;
	
	float dr = .05 * by;
	float doffs = .5 - dr;
	float x = (rn - .5) * doffs;
	x += sin(w + cos(w * 4.) * pow(sin(x), 2.)) * (doffs - abs(x));
	float y = cos(t + cos(t + cos(t) * .5)) * doffs;
	y += (grid_uv.x - x) * (grid_uv.x - x);
	vec2 dpos = grid_uv - vec2(x, y);
	float drop = smoothstep(dr, .01, length(dpos));
	
	float trail = smoothstep(dr, -dr, dpos.y);
	trail *= smoothstep(dr, .01, abs(dpos.x));
	trail *= smoothstep(-.5, y, grid_uv.y);
	
	float fade = 1. - clamp(fwidth(uv.x) * fade_distance, 0, 1);
	
	vec2 output = vec2(0);
	output += drop * drop_strength * by;
	output += trail * trail_strength;
	//if(grid_uv.x > .48 || grid_uv.y > .48) output.r = 1.;
	//return vec2(drop);
	return output * dpos * refraction * fade;
}

void fragment() {
	vec2 droplets = vec2(0);
	for(float i = 1.; i <= float(layers); i++){
		droplets += RainDrops(UV, scale * i * .2, speed *i * .12, wiggle * i * .7);
	}
	ALBEDO = textureLod(screen_tex, SCREEN_UV - droplets, smoothstep(.01, .001, droplets.x) * blur).rgb;
}