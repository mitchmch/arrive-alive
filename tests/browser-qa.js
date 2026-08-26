const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const path = require('node:path');

(async () => {
  const browser = await chromium.launch({headless: true});
  const context = await browser.newContext({viewport: {width: 390, height: 844}});
  const page = await context.newPage();
  const pageErrors = [];
  page.on('pageerror', error => pageErrors.push(error.message));
  await page.goto('http://127.0.0.1:3000', {waitUntil: 'domcontentloaded'});
  await page.waitForSelector('[data-testid="button-sign-in"]', {state: 'visible'});
  await page.getByTestId('button-sign-in').click();
  await page.locator('#loginPhone').fill('admin');
  await page.locator('#loginPin').fill('1234');
  await page.getByTestId('button-submit-login').click();
  await page.waitForSelector('[data-testid="screen-admin"].active');

  assert.match(await page.getByTestId('admin-sync-health').innerText(), /not durable|Local fallback/i);
  await page.getByTestId('input-admin-agency').fill('QA Transit');
  await page.getByTestId('input-admin-agency-score').fill('92');
  await page.getByTestId('button-add-agency').click();
  await page.waitForSelector('[data-testid^="admin-agency-"] >> text=QA Transit');
  await page.screenshot({path: path.join(__dirname, 'admin-mobile.png'), fullPage: false});

  await page.getByTestId('button-back-admin').click();
  await page.waitForSelector('[data-testid="screen-profile"].active');
  await page.getByTestId('input-profile-photo').setInputFiles({
    name: 'unsafe.txt',
    mimeType: 'text/plain',
    buffer: Buffer.from('not an image'),
  });
  assert.match(await page.getByTestId('profile-error').innerText(), /JPEG, PNG or WebP/);

  await page.evaluate(() => {
    const session = getAASession();
    aaRepository.upsert('journeys', {
      id: 'journey-visual-qa',
      ownerId: `user-${session.phone}`,
      endedAt: new Date().toISOString(),
      mode: 'car',
      summary: {distanceKm: 12.4, durationSeconds: 1620, violations: 1},
    });
    renderProfile();
  });
  await page.waitForSelector('[data-testid="journey-history-journey-visual-qa"]');
  await page.screenshot({path: path.join(__dirname, 'profile-mobile.png'), fullPage: false});

  const layout = await page.evaluate(() => ({
    bodyWidth: document.body.scrollWidth,
    viewportWidth: innerWidth,
    activeWidth: document.querySelector('.screen.active').getBoundingClientRect().width,
    historyVisible: Boolean(document.querySelector('[data-testid="journey-history-journey-visual-qa"]')),
  }));
  assert.equal(layout.bodyWidth, layout.viewportWidth);
  assert.ok(layout.activeWidth <= layout.viewportWidth);
  assert.equal(layout.historyVisible, true);
  assert.deepEqual(pageErrors, []);
  await browser.close();
  console.log('Browser QA passed:', layout);
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
