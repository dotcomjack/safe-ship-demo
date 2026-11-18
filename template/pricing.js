// Price shown on the homepage. Cents in, dollars out.
export function formatPrice(cents) {
  return `$${(cents / 100).toFixed(3)}`;
}
