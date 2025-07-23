#version 300 es

precision mediump float;
uniform vec3 mainColor;
uniform float brightness;
uniform float offset;
uniform float paletteWidth;

in vec2 uv;
out vec4 color;

void main() {
	vec3 mainColor = mainColor / 255.0;
	vec3 lightColor = mix(mainColor, vec3(1.0), brightness);
	float x = floor(uv.x * paletteWidth - offset) / paletteWidth;
	color = vec4(mix(mainColor, lightColor, x), 1.0);
	color.rgb = max(vec3(0.0), min(vec3(1.0), color.rgb));
}
