<style>
	:global(body) {
		margin: 0;
		display: flex;
		flex-flow: column nowrap;
		min-height: 100vh;
		background: #2e2e2e;
		color: #e0e0e0;
		font-family: Arial, Helvetica, sans-serif;
		font-size: 13pt;
	}

	main {
		flex: 1;
		display: flex;
		flex-flow: row nowrap;
	}

	.canvas-container {
		flex: 2;
		position: relative;
		overflow: hidden;
	}

	canvas {
		position: absolute;
		inset: 0;
	}

	form {
		flex: 1;
		display: flex;
		flex-flow: column;
		padding: 1rem;
		gap: 1rem;
	}

	ul {
		font-family: monospace;
		list-style: none;
		padding: 0;
		margin: 0;
	}

	li {
		padding-left: 0.5rem;
		border-left: solid 1rem;
	}

	li.main-color {
		font-weight: bold;
	}

	li > button {
		font: inherit;
		appearance: none;
		background: none;
		color: inherit;
		border: none;
		cursor: pointer;
	}

	li > button:hover {
		text-decoration: underline;
	}
</style>

<main>
	<div bind:this={canvasContainer} class="canvas-container">
		<canvas
			bind:this={canvas}
			width={canvasWidth}
			height={canvasHeight}
		></canvas>
	</div>
	<form>
		<div>Main color: {mainColor}</div>
		<input type="color" bind:value={mainColor}/>
		<div>Brightness: {brightness}</div>
		<input
			type="range"
			min="0.0"
			max="1.0"
			step="0.1"
			bind:value={brightness}
		/>
		<div>Offset: {offset}</div>
		<input
			type="range"
			min="0"
			max="{paletteWidth - 1}"
			step="1"
			bind:value={offset}
		/>
		<div>Gamma: {gamma}</div>
		<input
			type="range"
			min="0.1"
			max="3.3"
			step="0.1"
			bind:value={gamma}
		/>
		<div>Colors (click to copy):</div>
		<ul>
			{#each computedColors as c}
				<li
					class:main-color={mainColor === c}
					style="border-color: {c}"
				>
					<button onclick={() => copyToClipboard(c)}>
						{c}
					</button>
				</li>
			{/each}
		</ul>
	</form>
</main>

<script lang="ts">
	import { onMount } from "svelte";
	import fullscreenQuadVertexShaderSource from "../resources/fullscreen_quad.vertex.glsl?raw";
	import generatePaletteFragmentShaderSource from "../resources/generate_palette.fragment.glsl?raw";
	import renderTextureFragmentShaderSource from "../resources/render_texture.fragment.glsl?raw";
	import { throwIfNullish } from "$lib/null";

	const paletteWidth = 10;
	const paletteHeight = 1;
	let computedColors: string[] = $state([]);
	let canvasContainer: HTMLDivElement;
	let canvasWidth = $state(1);
	let canvasHeight = $state(1);
	let canvas: HTMLCanvasElement;
	let gl: WebGL2RenderingContext;
	let texture: WebGLTexture;
	let framebuffer: WebGLFramebuffer;
	let generatePaletteProgram: WebGLProgram;
	let renderTextureProgram: WebGLProgram;
	let mainColor = $state("#2c4888");
	let mainColorRgb = $derived.by(() => hexToRgb(mainColor.slice(1)));
	let mainColorLocation: WebGLUniformLocation;
	let brightness = $state(0.8);
	let brightnessLocation: WebGLUniformLocation;
	let offset = $state(3);
	let offsetLocation: WebGLUniformLocation;
	let paletteWidthLocation: WebGLUniformLocation;
	let gamma = $state(1.0);
	let gammaLocation: WebGLUniformLocation;
	let inputTextureLocation: WebGLUniformLocation;

	onMount(() => {
		let lastTimeout: ReturnType<typeof setTimeout> | undefined;
		const canvasResizeObserver = new ResizeObserver(elements => {
			if (lastTimeout !== undefined) {
				clearTimeout(lastTimeout);
			}

			lastTimeout = setTimeout(() => {
				const rect = elements[0].contentRect;
				canvasWidth = Math.round(rect.width);
				canvasHeight = Math.round(rect.height);
				lastTimeout = undefined;
			}, 100);
		});
		canvasResizeObserver.observe(canvasContainer);
		const rect = canvasContainer.getBoundingClientRect();
		canvasWidth = Math.round(rect.width);
		canvasHeight = Math.round(rect.height);

		gl = throwIfNullish(
			canvas.getContext("webgl2"),
			"Failed to get canvas WebGL context",
		);

		const fullscreenQuadVertexShader = createShader(
			"fullscreenQuadVertexShader",
			gl,
			gl.VERTEX_SHADER,
			fullscreenQuadVertexShaderSource,
		);
		const generatePaletteFragmentShader = createShader(
			"generatePaletteFragmentShader",
			gl,
			gl.FRAGMENT_SHADER,
			generatePaletteFragmentShaderSource,
		);
		const renderTextureFragmentShader = createShader(
			"renderTextureFragmentShader",
			gl,
			gl.FRAGMENT_SHADER,
			renderTextureFragmentShaderSource,
		);

		generatePaletteProgram = gl.createProgram();
		gl.attachShader(generatePaletteProgram, fullscreenQuadVertexShader);
		gl.attachShader(generatePaletteProgram, generatePaletteFragmentShader);
		gl.linkProgram(generatePaletteProgram);

		renderTextureProgram = gl.createProgram();
		gl.attachShader(renderTextureProgram, fullscreenQuadVertexShader);
		gl.attachShader(renderTextureProgram, renderTextureFragmentShader);
		gl.linkProgram(renderTextureProgram);

		texture = gl.createTexture();
		gl.bindTexture(gl.TEXTURE_2D, texture);
		gl.texImage2D(
			gl.TEXTURE_2D,
			0,
			gl.RGBA,
			paletteWidth,
			paletteHeight,
			0,
			gl.RGBA,
			gl.UNSIGNED_BYTE,
			null,
		);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

		framebuffer = gl.createFramebuffer();
		gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
		gl.framebufferTexture2D(
			gl.FRAMEBUFFER,
			gl.COLOR_ATTACHMENT0,
			gl.TEXTURE_2D,
			texture,
			0,
		);

		if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) !== gl.FRAMEBUFFER_COMPLETE) {
			throw new Error("Framebuffer is not complete");
		}

		// Full screen rectangle.
		const position = new Float32Array([
			-1, -1, // Bottom left.
			 1, -1, // Bottom right.
			-1,  1, // Top left.
			 1,  1, // Top right.
		]);
		const positionBuffer = gl.createBuffer();
		gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
		gl.bufferData(gl.ARRAY_BUFFER, position, gl.STATIC_DRAW);

		for (const program of [generatePaletteProgram, renderTextureProgram]) {
			const positionLocation = gl.getAttribLocation(program, "position");
			gl.enableVertexAttribArray(positionLocation);
			gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
			gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0);
		}

		mainColorLocation = throwIfNullish(
			gl.getUniformLocation(generatePaletteProgram, "mainColor"),
			"Failed to get mainColor uniform location",
		);

		brightnessLocation = throwIfNullish(
			gl.getUniformLocation(generatePaletteProgram, "brightness"),
			"Failed to get brightness uniform location",
		);

		offsetLocation = throwIfNullish(
			gl.getUniformLocation(generatePaletteProgram, "offset"),
			"Failed to get offset uniform location",
		);

		paletteWidthLocation = throwIfNullish(
			gl.getUniformLocation(generatePaletteProgram, "paletteWidth"),
			"Failed to get paletteWidth uniform location",
		);

		gammaLocation = throwIfNullish(
			gl.getUniformLocation(generatePaletteProgram, "gamma"),
			"Failed to get gamma uniform location",
		);

		inputTextureLocation = throwIfNullish(
			gl.getUniformLocation(renderTextureProgram, "inputTexture"),
			"Failed to get inputTexture uniform location",
		);
	});

	function onGeneratePalette() {
		gl.viewport(0, 0, paletteWidth, paletteHeight);
		gl.useProgram(generatePaletteProgram);
		gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);

		gl.uniform3f(mainColorLocation, ...mainColorRgb);
		gl.uniform1f(brightnessLocation, brightness);
		gl.uniform1f(offsetLocation, offset);
		gl.uniform1f(paletteWidthLocation, paletteWidth);
		gl.uniform1f(gammaLocation, gamma);

		gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
	}

	function onRenderTexture() {
		gl.viewport(0, 0, canvasWidth, canvasHeight);
		gl.bindFramebuffer(gl.FRAMEBUFFER, null);
		gl.useProgram(renderTextureProgram);

		// I think I should use this but it creates a warning and the program
		// works just fine without it.
		// gl.uniform1f(inputTextureLocation, 0);

		gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
	}

	function updateComputedColors() {
		const pixelData = new Uint8Array(paletteWidth * 4);
		gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
		gl.readPixels(0, 0, paletteWidth, paletteHeight, gl.RGBA, gl.UNSIGNED_BYTE, pixelData);

		computedColors = Array.from({ length: paletteWidth }, (_, i) => {
			const index = i * 4;
			return `#${rgbToHex(pixelData[index], pixelData[index + 1], pixelData[index + 2])}`;
		});
	}

	$effect(() => {
		onGeneratePalette();
		updateComputedColors();
		onRenderTexture();
	});

	function createShader(
		name: string,
		gl: WebGL2RenderingContext,
		type: GLenum,
		source: string
	): WebGLShader {
		const shader = gl.createShader(type);
		if (shader === null) {
			throw new Error("Failed to create shader");
		}

		gl.shaderSource(shader, source);
		gl.compileShader(shader);

		if (gl.getShaderParameter(shader, gl.COMPILE_STATUS) === true) {
			return shader;
		}

		const log = gl.getShaderInfoLog(shader);
		gl.deleteShader(shader);
		throw new Error(`Failed to compile shader "${name}", info log:\n${log}`);
	}

	function hexToRgb(hex: string): [number, number, number] {
		const dec = parseInt(hex, 16);
		return [dec >> 16 & 0xFF, dec >> 8 & 0xFF, dec & 0xFF];
	}

	function rgbToHex(red: number, green: number, blue: number): string {
		const dec = red << 16 | green << 8 | blue;
		return dec.toString(16).padStart(6, "0");
	}

	async function copyToClipboard(text: string): Promise<void> {
		try {
			await navigator.clipboard.writeText(text);
		} catch (error) {
			console.error("Failed to copy to clipboard:", error);
		}
	}
</script>
