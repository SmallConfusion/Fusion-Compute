#[compute]
#version 450

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Agents {
	float data[];
}
agents;

layout(r32f, binding = 1) restrict uniform image2D trailmap;

layout(push_constant) uniform PushConstants {
	float trailStrength;
	float width;
	float height;
	float sensor_angle;
	float sensor_distance;
	float speed;
	float turning;
	float random;
}
pc;


vec2 rotate(vec2 v, float a) {
	return vec2(
		v.x * cos(a) - v.y * sin(a),
		v.x * sin(a) + v.y * cos(a)
	);
}

float random(float s) {
	return fract(sin(s * 358.294459) * 253853.83598);
}

void main() {
	// Setup
	vec2 pos = vec2(
		agents.data[gl_GlobalInvocationID.x * 4],
		agents.data[gl_GlobalInvocationID.x * 4 + 1]
	);

	vec2 vel = vec2(
		agents.data[gl_GlobalInvocationID.x * 4 + 2],
		agents.data[gl_GlobalInvocationID.x * 4 + 3]
	);

	// if (any(isnan(pos)) || any(isnan(vel)) || any(isinf(pos)) || any(isinf(vel))) {
		// pos = vec2(pc.width, pc.height) / 2.0;
		// vel = vec2(
			// random(float(gl_GlobalInvocationID.x)),
			// random(float(gl_GlobalInvocationID.x) + 0.245)
		// );
	// }

	// Wall collision
	if (pos.x < 0 || pos.x > pc.width) {
		pos.x = clamp(pos.x, 0, pc.width);
		vel.x = -vel.x;
	}

	if (pos.y < 0 || pos.y > pc.width) {
		pos.y = clamp(pos.y, 0, pc.width);
		vel.y = -vel.y;
	}


	// Sensors
	vec2 forward = normalize(vel) * pc.sensor_distance;
	vec2 left = rotate(forward, pc.sensor_angle);
	vec2 right = rotate(forward, -pc.sensor_angle);
	
	float f_val = imageLoad(trailmap, ivec2(clamp(pos + forward, vec2(0), vec2(pc.width, pc.height)))).r;
	float l_val = imageLoad(trailmap, ivec2(clamp(pos + left, vec2(0), vec2(pc.width, pc.height)))).r;
	float r_val = imageLoad(trailmap, ivec2(clamp(pos + right, vec2(0), vec2(pc.width, pc.height)))).r;

	vec2 max_dir = forward;

	if (l_val > f_val) {
		max_dir = left;
	}

	if (r_val > max(f_val, l_val)) {
		max_dir = right;
	}

	// Physics
	vel += max_dir * pc.turning; 

	vel = normalize(vel) * pc.speed;
	vel += rotate(forward, random(float(gl_GlobalInvocationID) + dot(pos, vel)) * 6.28318530718) * pc.random;

	// Should use atomic add here I think, but idk how to do that.
	float under = imageLoad(trailmap, ivec2(pos)).r;

	imageStore(trailmap, ivec2(pos), vec4(pc.trailStrength + under));

	pos += vel;

	// Store
	agents.data[gl_GlobalInvocationID.x * 4] = pos.x;
	agents.data[gl_GlobalInvocationID.x * 4 + 1] = pos.y;
	agents.data[gl_GlobalInvocationID.x * 4 + 2] = vel.x;
	agents.data[gl_GlobalInvocationID.x * 4 + 3] = vel.y;
}