#version 300 es

precision mediump float;

uniform sampler2D inputTexture;

in vec2 uv;
out vec4 color;

void main() {
	color = texture(inputTexture, uv);
}
