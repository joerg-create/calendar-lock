// Renders the app icon variants as 1024x1024 PNGs from SVG.
const { chromium } = require('playwright');

function svg(variant) {
  const dark = variant === 'dark', tinted = variant === 'tinted';
  const bg = tinted
    ? `<rect width="1024" height="1024" fill="#000"/>`
    : `<defs>
        <linearGradient id="bg" x1="0" y1="0" x2="0.35" y2="1">
          <stop offset="0" stop-color="${dark ? '#05060d' : '#141a3d'}"/>
          <stop offset="1" stop-color="${dark ? '#0d1530' : '#1f5f7a'}"/>
        </linearGradient>
        <filter id="blur" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="70"/></filter>
       </defs>
       <rect width="1024" height="1024" fill="url(#bg)"/>
       <g filter="url(#blur)" opacity="${dark ? 0.55 : 0.8}">
         <ellipse cx="300" cy="230" rx="420" ry="120" fill="#5b6cf2" transform="rotate(-18 300 230)"/>
         <ellipse cx="760" cy="330" rx="380" ry="110" fill="#3ec5d8" transform="rotate(14 760 330)"/>
         <ellipse cx="520" cy="900" rx="460" ry="140" fill="#9c5fe9"/>
       </g>`;
  const card = tinted ? '#ffffff' : (dark ? '#e9ecf7' : '#ffffff');
  const cardOpacity = tinted ? 0.95 : 1;
  const head = tinted ? '#bdbdbd' : '#ff6b5e';
  const line = tinted ? '#9a9a9a' : '#c9cfe0';
  const c1 = tinted ? '#7a7a7a' : '#ff6b5e', c2 = tinted ? '#8a8a8a' : '#3a8ef6', c3 = tinted ? '#9a9a9a' : '#34c77b';
  const lockFill = tinted ? '#ffffff' : '#ffffff';
  const lockStroke = tinted ? '#000' : (dark ? '#0d1530' : '#18234f');
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
    ${bg}
    <g transform="translate(0,10)">
      <!-- calendar sheet -->
      <rect x="232" y="250" width="560" height="560" rx="92" fill="${card}" opacity="${cardOpacity}"/>
      <path d="M232 342 a92 92 0 0 1 92 -92 h376 a92 92 0 0 1 92 92 v44 h-560 z" fill="${head}"/>
      <rect x="352" y="196" width="40" height="112" rx="20" fill="${card}"/>
      <rect x="632" y="196" width="40" height="112" rx="20" fill="${card}"/>
      <!-- agenda lines -->
      <rect x="300" y="452" width="26" height="62" rx="13" fill="${c1}"/>
      <rect x="356" y="468" width="300" height="30" rx="15" fill="${line}"/>
      <rect x="300" y="560" width="26" height="62" rx="13" fill="${c2}"/>
      <rect x="356" y="576" width="240" height="30" rx="15" fill="${line}"/>
      <rect x="300" y="668" width="26" height="62" rx="13" fill="${c3}"/>
      <rect x="356" y="684" width="170" height="30" rx="15" fill="${line}"/>
      <!-- padlock badge -->
      <g transform="translate(700,700) scale(0.86)">
        <circle r="162" fill="${tinted ? "#000" : card}"/><circle r="150" fill="${lockStroke}"/>
        <path d="M-50 -18 v-38 a50 50 0 0 1 100 0 v38" fill="none" stroke="${lockFill}" stroke-width="26" stroke-linecap="round"/>
        <rect x="-76" y="-22" width="152" height="118" rx="30" fill="${lockFill}"/>
        <circle cx="0" cy="30" r="17" fill="${lockStroke}"/>
        <rect x="-7" y="30" width="14" height="36" rx="7" fill="${lockStroke}"/>
      </g>
    </g>
  </svg>`;
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 });
  for (const v of ['light', 'dark', 'tinted']) {
    await page.setContent(`<html><body style="margin:0">${svg(v)}</body></html>`);
    await page.locator('svg').screenshot({ path: `AppIcon-${v}.png`, omitBackground: false });
  }
  // Preview with iOS-like mask at small sizes.
  await page.setContent(`<html><body style="margin:0;background:#888;display:flex;gap:30px;padding:30px;align-items:center">
    ${['light','dark','tinted'].map(v=>`<img src="file://${process.cwd()}/AppIcon-${v}.png" style="width:180px;border-radius:40px">`).join('')}
    <img src="file://${process.cwd()}/AppIcon-light.png" style="width:60px;border-radius:13px">
  </body></html>`);
  await page.screenshot({ path: 'preview.png', clip: { x: 0, y: 0, width: 760, height: 240 } });
  await browser.close();
})();
