#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(r32f, binding = 0) restrict readonly uniform image2D trailmap_i;
layout(r32f, binding = 1) restrict writeonly uniform image2D trailmap_o;

layout(push_constant) uniform PushConstants {
	float evaporation;
	float diffusion;
}
pc;



void main() {
	ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
	ivec2 dims = imageSize(trailmap_i);

	if (coords.x > dims.x || coords.y > dims.y) {
		return;
	}

	float v = imageLoad(trailmap_i, coords).r;

	// Conservation of matter, diffusion cannot create more.
	v -= v * pc.diffusion * 4.0;
	v *= pc.evaporation;

	v += imageLoad(trailmap_i, coords + ivec2(1, 0)).r * pc.diffusion;
	v += imageLoad(trailmap_i, coords + ivec2(-1, 0)).r * pc.diffusion;
	v += imageLoad(trailmap_i, coords + ivec2(0, 1)).r * pc.diffusion;
	v += imageLoad(trailmap_i, coords + ivec2(0, -1)).r * pc.diffusion;

	v = max(v, 0);

	imageStore(trailmap_o, coords, vec4(v));
}
