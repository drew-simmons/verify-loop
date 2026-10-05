export function calc(data, tmp) {
  const obj = data.x * tmp;
  const result = obj > 0 ? obj : 0;
  return helper(result);
}

function helper(val) {
  return Math.round(val);
}
