// The number fields of the planning controls, shared by the timetable page
// and today's plan on the day dispatch page.

// A number field's whole value within the range; otherwise the fallback,
// written back into the field so the page and the layout agree.
export function wholeInRange(input, [min, max], fallback) {
  const value = Number(input.value)
  const ok = input.value.trim() !== "" && Number.isInteger(value) && value >= min && value <= max
  if (!ok) input.value = fallback
  return ok ? value : fallback
}
