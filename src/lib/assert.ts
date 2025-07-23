import { isNullish } from "./null";

class AssertionError extends Error {
	public constructor(message: string) {
		super(`Assertion failed: ${message}`);
	}
}

export function assert(condition: boolean, message: string): condition is true {
	if (condition === false) {
		throw new AssertionError(message);
	}

	return condition;
}

export function assertNotNullish(
	value: NonNullable<unknown> | null | undefined,
	name: string,
): value is NonNullable<unknown> {
	if (isNullish(value)) {
		throw new AssertionError(`${name} is nullish`);
	}

	return true;
}
