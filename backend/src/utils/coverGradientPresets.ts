import crypto from 'crypto';

/** Пресеты обложки профиля: по 3 цвета #RRGGBB (как в приложении). */
const PRESETS: ReadonlyArray<readonly [string, string, string]> = [
  ['#E64444', '#FF6E82', '#FEBC2F'],
  ['#6C5CE7', '#A29BFE', '#FD79A8'],
  ['#0984E3', '#74B9FF', '#55EFC4'],
  ['#00B894', '#00CEC9', '#FDCB6E'],
  ['#E17055', '#FDCB6E', '#D63031'],
  ['#A29BFE', '#FD79A8', '#FDCB6E'],
  ['#FF7675', '#FAB1A0', '#FFEAA7'],
  ['#2D3436', '#636E72', '#B2BEC3'],
  ['#D63031', '#E84393', '#6C5CE7'],
  ['#00CEC9', '#81ECEC', '#FFFFFF'],
];

export function randomCoverGradientColors(): string[] {
  const i = crypto.randomInt(0, PRESETS.length);
  const p = PRESETS[i]!;
  return [p[0], p[1], p[2]];
}
