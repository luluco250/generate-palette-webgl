export class NullishValueError extends Error {}

export function isNullish(
	value: NonNullable<unknown> | null | undefined,
): value is NonNullable<unknown> {
	return value === null || value === undefined;
}

export function throwIfNullish<T extends NonNullable<unknown>>(
	value: T | null | undefined,
	message = "Value is nullish",
): T {
	if (isNullish(value)) {
		throw new NullishValueError(message);
	}

	return value as unknown as T;
}
