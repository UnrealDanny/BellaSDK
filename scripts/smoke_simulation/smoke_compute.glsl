#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

// FIXED: Explicitly added set = 0 to prevent binding errors.
layout(set = 0, binding = 0, rgba8) uniform restrict image3D smoke_grid;

struct Hole {
    vec3 start;
    float radius;
    vec3 end;
    float age;
};

layout(set = 0, binding = 1, std430) restrict readonly buffer HoleBuffer {
    Hole holes[];
};

layout(set = 0, binding = 2) uniform sampler3D noise_texture;

layout(push_constant, std430) uniform Params {
    vec3 player_pos;
    float num_holes;
    
    vec3 grid_pos;
    float delta_time;
    
    vec3 grid_size; 
    float time;         
    
    float hole_clear_intensity;
    float swirl_strength;
    float swirl_frequency;
    float player_radius;
    
    float z_offset;
    float heal_rate;
    float pad1; 
    float pad2;
} params;

// --- UTILITIES ---
struct SegmentHit {
    float dist;
    vec3 closestPoint;
    vec3 radialVector; 
};

SegmentHit dist_to_segment_detailed(vec3 p, vec3 a, vec3 b) {
    vec3 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    vec3 closest = a + ba * h;
    SegmentHit hit;
    hit.closestPoint = closest;
    hit.radialVector = p - closest;
    hit.dist = length(hit.radialVector);
    return hit;
}

void main() {
    ivec3 voxel_pos = ivec3(
        gl_GlobalInvocationID.x, 
        gl_GlobalInvocationID.y, 
        gl_GlobalInvocationID.z + int(params.z_offset)
    );
    
    vec3 voxel_size = params.grid_size / 128.0; 
    vec3 world_pos = params.grid_pos + (vec3(voxel_pos) * voxel_size);
    
    vec4 current_data = imageLoad(smoke_grid, voxel_pos);
    float density = current_data.r;
    
    vec3 flow = vec3(params.time * 0.15, params.time * 0.25, params.time * 0.1);
    vec3 warp_coords = world_pos * 0.05; 
    
    // FIXED: Replaced texture() with textureLod() for safe compute sampling
    vec3 distortion = vec3(
        textureLod(noise_texture, warp_coords + flow, 0.0).r,
        textureLod(noise_texture, warp_coords - flow, 0.0).r,
        textureLod(noise_texture, warp_coords + vec3(flow.y, -flow.z, flow.x), 0.0).r
    );
    
    // FIXED: Replaced texture() with textureLod()
    float billow = textureLod(
        noise_texture, (warp_coords) + (distortion * 0.5), 0.0
    ).r;
    
    float target_density = smoothstep(0.3, 0.75, billow); 
    density = min(
        density + (params.heal_rate * params.delta_time), 
        target_density
    );
    
    // Player Interaction
    float player_dist = distance(world_pos, params.player_pos);
    if (player_dist < params.player_radius) {
        float clear_amount = 1.0 - smoothstep(
            params.player_radius * 0.3, 
            params.player_radius, 
            player_dist
        ); 
        density -= clear_amount;
    }
    
    // Bullet Interaction
    int hole_count = int(params.num_holes);
    for (int i = 0; i < hole_count; i++) {
        float hole_normalized_age = holes[i].age * params.heal_rate;
        if (hole_normalized_age > 1.0) continue; 
        
        float base_radius = holes[i].radius;
        float dynamic_radius = base_radius * (1.0 + hole_normalized_age * 0.5); 
        
        float max_effect_distance = dynamic_radius * 2.5; 
        
        vec3 min_bound = min(holes[i].start, holes[i].end) - vec3(max_effect_distance);
        vec3 max_bound = max(holes[i].start, holes[i].end) + vec3(max_effect_distance);
        
        if (any(lessThan(world_pos, min_bound)) || any(greaterThan(world_pos, max_bound))) {
            continue;
        }

        SegmentHit hit = dist_to_segment_detailed(
            world_pos, holes[i].start, holes[i].end
        );
        
        if (hit.dist < dynamic_radius * 2.0) { 
            float clear_mask = 1.0 - smoothstep(0.0, dynamic_radius, hit.dist);
            
            float swirl_fade_over_time = smoothstep(1.0, 0.0, hole_normalized_age);
            float swirl_mask = smoothstep(
                base_radius * 0.5, base_radius, hit.dist
            ) * (1.0 - smoothstep(base_radius, base_radius * 2.5, hit.dist));
            
            swirl_mask *= swirl_fade_over_time; 
            
            vec3 pellet_dir = normalize(holes[i].end - holes[i].start);
            vec3 rotAxis = normalize(cross(pellet_dir, hit.radialVector)); 
            
            vec3 turbulent_coords = (world_pos * params.swirl_frequency * 0.05) + (distortion * 0.5);
            turbulent_coords += rotAxis * (params.swirl_strength * swirl_fade_over_time);
            
            // FIXED: Replaced texture() with textureLod()
            float raw_noise = textureLod(noise_texture, turbulent_coords, 0.0).r;
            float turbulence = abs(2.0 * raw_noise - 1.0);
            
            density -= (clear_mask * params.hole_clear_intensity);
            density += (turbulence * swirl_mask * params.swirl_strength);
        }
    }
    
    density = clamp(density, 0.0, 1.0);
    imageStore(smoke_grid, voxel_pos, vec4(density, 0.0, 0.0, 1.0));
}
