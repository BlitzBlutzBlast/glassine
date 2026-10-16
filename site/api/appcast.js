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
import { track } from '@vercel/analytics/server';

const feed = () => readFileSync(join(process.cwd(), 'feed', 'appcast.xml'), 'utf8');

export default async function handler(req, res) {
  const ua = req.headers['user-agent'] || '';
  const version = (/Glassine\/([\d.]+)/.exec(ua) || [])[1] || 'unknown';
  const sparkle = (/Sparkle\/([\d.]+)/.exec(ua) || [])[1] || 'none';
  try {
    await track('appcast', { version, sparkle }, { request: req });
  } catch {
    // Analytics not on, or not reachable: the feed still goes out.
  }
  let xml;
  try {
    xml = feed();
  } catch (error) {
    res.status(500).send('The feed is missing from this deployment.');
    return;
  }
  res.setHeader('Content-Type', 'application/rss+xml; charset=utf-8');
  // Every check reaches this function, so every check is counted; the file
  // is small and the check is daily.
  res.setHeader('Cache-Control', 'no-store');
  res.status(200).send(xml);
}
