/**
 * Mirrors iOS `HomeRepository` / `HomeActiveMatch` Battle Score math for Edge-only copy (check-ins).
 * Not used for finalization winner resolution.
 */

export function effectiveBaselineSteps(baseline: number | null | undefined): number {
  if (baseline != null && Number.isFinite(baseline) && baseline > 0) {
    return Math.max(3000, baseline);
  }
  return 3000;
}

export function balanceMultiplier(myEffective: number, theirEffective: number): number {
  const higher = Math.max(myEffective, theirEffective);
  if (myEffective <= 0) return 1;
  return higher / myEffective;
}

/**
 * Battle Score for the player with `actualSteps`, using their baseline vs rival baseline.
 */
export function battleScore(
  actualSteps: number,
  myBaseline: number | null | undefined,
  theirBaseline: number | null | undefined,
): number {
  const myEff = effectiveBaselineSteps(myBaseline);
  const theirEff = effectiveBaselineSteps(theirBaseline);
  const mult = balanceMultiplier(myEff, theirEff);
  return Math.round(actualSteps * mult);
}
