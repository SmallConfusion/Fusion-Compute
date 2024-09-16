shader_type canvas_item;

void fragment() {
	float r = texture(TEXTURE, UV).r;

	r = r / (r + 1.0);

	COLOR.rgb = r * vec3(1);
}