#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba8, binding = 0) restrict uniform image2D image;


void main() {
	ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
	ivec2 dim = imageSize(image);

	if (coords.x > dim.x || coords.y > dim.y) {
		return;
	}

	vec2 uv = vec2(coords) / vec2(dim);

	vec4 c = vec4(uv.x, uv.y, 1.0, 1.0);

	imageStore(image, coords, c);
}