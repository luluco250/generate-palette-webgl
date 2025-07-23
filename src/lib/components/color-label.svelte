<style lang="scss">
	button {
		--color: #000000;
		display: block;
		text-align: start;
		font-family: monospace;
		font-weight: normal;
		font-size: inherit;
		appearance: none;
		background: none;
		color: inherit;
		border: none;
		border-left: solid 1rem var(--color);
		cursor: pointer;

		&.strong {
			font-weight: bold;
		}

		&:hover {
			text-decoration: underline;
		}
	}
</style>

<button
	style={`--color: ${color}; ${style ?? ""}`}
	onclick={() => onClick?.()}
>
	{color}
</button>

<script lang="ts">
	interface Props {
		color?: string;
		style?: string;
		onClick?: () => void;
	}

	let {
		color = "#000000",
		style,
		onClick,
	}: Props = $props();
</script>
