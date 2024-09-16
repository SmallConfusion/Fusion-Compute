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
	float time;
}
pc;


const float TAU = 6.28318530718;


vec2 rotate(vec2 v, float a) {
	return vec2(
		v.x * cos(a) - v.y * sin(a),
		v.x * sin(a) + v.y * cos(a)
	);
}

vec2 angle_vec(float a) {
	return vec2(cos(a), sin(a));
}

float random(vec2 st) {
	st = mod(st, vec2(1000));
    return fract(sin(dot(st.xy, vec2(12.9898,78.233)))*43758.5453123);
}

vec2 loop_screen(vec2 pos) {
	return mod(pos, vec2(pc.width, pc.height));
}


void main() {
	// Setup
	vec2 pos = vec2(
		agents.data[gl_GlobalInvocationID.x * 3],
		agents.data[gl_GlobalInvocationID.x * 3 + 1]
	);

	float angle = agents.data[gl_GlobalInvocationID.x * 3 + 2];

	pos = loop_screen(pos);

	// Sensors
	vec2 forward = angle_vec(angle) * pc.sensor_distance;
	vec2 left = angle_vec(angle - pc.sensor_angle) * pc.sensor_distance;
	vec2 right = angle_vec(angle + pc.sensor_angle) * pc.sensor_distance;
	
	float f_val = imageLoad(trailmap, ivec2(loop_screen(pos + forward))).r;
	float l_val = imageLoad(trailmap, ivec2(loop_screen(pos + left))).r;
	float r_val = imageLoad(trailmap, ivec2(loop_screen(pos + right))).r;

	// Steering
	float random_steer = 2.0 * (random(pc.time * pos * forward) - 0.5);

	if (f_val > max(l_val, r_val)) {
		// angle += 0;
	} else if (f_val < min(l_val, r_val)) {
		angle += pc.turning * random_steer;
	} else if (r_val > l_val) {
		angle += pc.turning + random_steer * pc.random;
	} else {
		angle -= pc.turning + random_steer * pc.random;
	}

	vec2 vel = angle_vec(angle) * pc.speed;

	// Should use atomic add here I think, but idk how to do that.
	float under = imageLoad(trailmap, ivec2(pos)).r;
	imageStore(trailmap, ivec2(pos), vec4(pc.trailStrength + under));

	pos += vel;

	// Store
	agents.data[gl_GlobalInvocationID.x * 3] = pos.x;
	agents.data[gl_GlobalInvocationID.x * 3 + 1] = pos.y;
	agents.data[gl_GlobalInvocationID.x * 3 + 2] = angle;
}