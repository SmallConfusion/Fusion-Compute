#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, binding = 0) restrict uniform image2D image;
layout(binding = 1) uniform sampler2D depth;

void main() {
	ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
	ivec2 dim = imageSize(image);

	if (coords.x > dim.x || coords.y > dim.y) {
		return;
	}

	vec2 uv = (vec2(coords) + 0.5) / vec2(dim);

	float depth_value = texelFetch(depth, coords, 0).r;
	vec4 color_value = imageLoad(image, coords);

	vec4 c = mix(color_value, vec4(0.4, 0.4, 0.4, 1.0), clamp(0.005 / depth_value, 0.0, 1.0));

	imageStore(image, coords, c);
}
