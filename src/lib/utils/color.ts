export function hexToRgb(hex: string): [number, number, number] {
	const dec = parseInt(hex, 16);
	return [dec >> 16 & 0xFF, dec >> 8 & 0xFF, dec & 0xFF];
}

export function rgbToHex(red: number, green: number, blue: number): string {
	const dec = red << 16 | green << 8 | blue;
	return dec.toString(16).padStart(6, "0");
}
