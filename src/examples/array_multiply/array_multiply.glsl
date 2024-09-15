#[compute]
#version 450

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Array {
	float data[];
}
array;

layout(push_constant) uniform PushConstants {
	float multiplier;
}
pc;


void main() {
	array.data[gl_GlobalInvocationID.x] *= pc.multiplier;
}