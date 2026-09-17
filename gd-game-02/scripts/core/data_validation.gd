class_name DataValidation
extends RefCounted

# JSON parses both integer and decimal tokens as numbers; booleans are distinct.
static func is_finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
