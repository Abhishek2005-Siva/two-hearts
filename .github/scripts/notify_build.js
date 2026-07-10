// Pings the developer's phone via FCM the moment a CI build finishes,
// with a direct link to the freshly-published release APK. Uses only
// Node's built-ins (no npm install) — same JWT-signing-a-service-account
// pattern as any other server-to-FCM call.
//
// Usage: node notify_build.js <path-to-service-account.json> <apk-url>

const fs = require('fs');
const crypto = require('crypto');

const [, , serviceAccountPath, apkUrl] = process.argv;

if (!serviceAccountPath || !apkUrl) {
  console.error('Usage: node notify_build.js <service-account.json> <apk-url>');
  process.exit(1);
}

function base64url(input) {
  return Buffer.from(input)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

async function main() {
  const sa = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claim = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claim))}`;
  const signature = crypto
    .createSign('RSA-SHA256')
    .update(unsigned)
    .sign(sa.private_key)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
  const jwt = `${unsigned}.${signature}`;

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  const tokenJson = await tokenRes.json();
  if (!tokenJson.access_token) {
    console.error('Failed to get access token:', JSON.stringify(tokenJson));
    process.exit(1);
  }

  const fcmRes = await fetch(
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenJson.access_token}`,
      },
      body: JSON.stringify({
        message: {
          topic: 'dev_builds',
          notification: {
            title: '📦 New Two Hearts build ready',
            body: 'Tap to download the APK',
          },
          android: {
            // Tapping the notification opens this link directly —
            // handled by the FCM SDK itself, no app code needed.
            fcmOptions: { link: apkUrl },
          },
        },
      }),
    }
  );
  const fcmJson = await fcmRes.json();
  console.log('FCM response:', JSON.stringify(fcmJson));
  if (!fcmRes.ok) process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
