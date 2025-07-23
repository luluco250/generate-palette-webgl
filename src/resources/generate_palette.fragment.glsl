#version 300 es

precision mediump float;
uniform vec3 mainColor;
uniform float contrast;
uniform float offset;
uniform float paletteWidth;
uniform float gamma;

in vec2 uv;
out vec4 color;

void main() {
	vec3 mainColor = pow(mainColor / 255.0, vec3(1.0 / gamma));
	vec3 lightColor = mix(mainColor, vec3(1.0), contrast);

	float palettePosition = floor(uv.x * paletteWidth - offset) / paletteWidth;
	color = vec4(mix(mainColor, lightColor, palettePosition), 1.0);

	color.rgb = max(vec3(0.0), min(vec3(1.0), color.rgb));
	color.rgb = pow(color.rgb, vec3(gamma));
}
