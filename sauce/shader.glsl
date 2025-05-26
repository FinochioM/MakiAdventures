/*

WELCOME, to the lovely land of shaders.

This is just a fragment shader, since it's all that's really needed most of the time.

Here's the Holy Bible -> https://thebookofshaders.com/

*/

// #shared with Quad_Flags definition (name doesn't matter, just value)
#define FLAG_background_pixels (1<<0)
#define FLAG_2 (1<<1)
#define FLAG_3 (1<<2)
bool has_flag(int flags, int flag) { return (flags & flag) != 0; }

layout(binding=0) uniform Shader_Data {
	mat4 ndc_to_world_xform;

	// this is more or less constant
	vec4 bg_repeat_tex0_atlas_uv;

	float time_of_day;
	int light_count;
	vec3 _padding;

	vec4 light_positions[8];
	vec4 light_colors[8];
};

float calculate_light(vec2 world_pos, vec4 light_pos, vec4 light_color) {
	float dist = distance(world_pos.xy, light_pos.xy);
	float radius = light_pos.w;

	float attenuation = 1.0 - smoothstep(0.0, radius, dist);
	attenuation = pow(attenuation, 2.0);

	return attenuation * light_color.a;
}

void main() {

	int tex_index = int(bytes.x * 255.0);

	int flags = int(bytes.z * 255.0);

	vec2 world_pixel = (ndc_to_world_xform * vec4(pos.xy, 0, 1)).xy;

	vec3 lightning = vec3(0.0);

	bool is_night = (time_of_day >= 0.5 || time_of_day < 0.1);

	vec4 tex_col = vec4(1.0);
	if (tex_index == 0) {
		tex_col = texture(sampler2D(tex0, default_sampler), uv);
	} else if (tex_index == 1) {
		// this is text, it's only got the single .r channel so we stuff it into the alpha
		tex_col.a = texture(sampler2D(font_tex, default_sampler), uv).r;
	}

	col_out = tex_col;

	// example of using a flag to override a pixel and just do whatever with it.
	// here, we're repeating a texture every 128 square pixels
	if (has_flag(flags, FLAG_background_pixels)) {
		float wrap_length = 128.0;
		vec2 uv = world_pixel / wrap_length;
		uv = local_uv_to_atlas_uv(uv, bg_repeat_tex0_atlas_uv);
		vec4 img = texture(sampler2D(tex0, default_sampler), uv);
		col_out.rgb = img.rgb;
	}

	// add :pixel stuff here ^

	if (is_night) {
		for (int i = 0; i < light_count && i < 8; i++) {
			float light_factor = calculate_light(world_pixel, light_positions[i], light_colors[1]);
			lightning += light_colors[i].rgb * light_factor;
		}

		float ambient = 0.2;
		lightning = max(lightning, vec3(ambient, ambient, ambient));
	} else {
		lightning = vec3(1.0);
	}

	col_out *= lightning;

	col_out.rgb = mix(col_out.rgb, color_override.rgb, color_override.a);
}