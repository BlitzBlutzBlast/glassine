// The update feed, served by a function rather than as a file, so that each
// check can be counted. The direct download asks glassine.ink for this once
// a day (Sparkle, SUFeedURL in Info.plist); the request carries the app's
// version in its User-Agent and nothing else. The count goes to Vercel's Web
// Analytics as a custom event, `appcast`, with the version — no cookie, no
// IP address kept; Vercel tells visitors apart by a hash that changes daily —
// so the number of copies in use, by version, shows in the project's
// Analytics tab and nowhere else. Counting never gets in the way of the
// feed: if it fails, the feed is served anyway.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { track } from '@vercel/analytics/server';

/// The feed: the file bundled beside this function (vercel.json's
/// includeFiles), looked for next to the function and at the working
/// directory; failing both, the same file as the deployment serves it
/// statically at /feed/appcast.xml.
async function feed(req) {
  const here = fileURLToPath(new URL('.', import.meta.url));
  for (const path of [join(here, '..', 'feed', 'appcast.xml'), join(process.cwd(), 'feed', 'appcast.xml')]) {
    try { return readFileSync(path, 'utf8'); } catch {}
  }
  const host = process.env.VERCEL_URL || req.headers.host;
  const response = await fetch(`https://${host}/feed/appcast.xml`, { headers: { 'x-vercel-protection-bypass': process.env.VERCEL_AUTOMATION_BYPASS_SECRET || '' } });
  if (!response.ok) throw new Error(`feed ${response.status}`);
  return await response.text();
}

export default async function handler(req, res) {
  const ua = req.headers['user-agent'] || '';
  const version = (/Glassine\/([\d.]+)/.exec(ua) || [])[1] || 'unknown';
  const sparkle = (/Sparkle\/([\d.]+)/.exec(ua) || [])[1] || 'none';
  let xml;
  try {
    xml = await feed(req);
  } catch (error) {
    res.status(500).send('The feed is missing from this deployment: ' + (error && error.message));
    return;
  }
  try {
    await track('appcast', { version, sparkle }, { request: req });
  } catch {
    // Analytics not on, or not reachable: the feed still goes out.
  }
  res.setHeader('Content-Type', 'application/rss+xml; charset=utf-8');
  // Every check reaches this function, so every check is counted; the file
  // is small and the check is daily.
  res.setHeader('Cache-Control', 'no-store');
  res.status(200).send(xml);
}
