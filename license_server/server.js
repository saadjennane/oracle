import express from 'express';
import fs from 'fs/promises';
import path from 'path';

const app = express();
app.use(express.json());

const PORT = Number(process.env.PORT || 8787);
const LICENSE_PROVIDER = String(process.env.LICENSE_PROVIDER || 'lemonsqueezy').toLowerCase();
const API_KEY = process.env.LEMON_SQUEEZY_API_KEY || '';
const STORE_ID = String(process.env.LEMON_SQUEEZY_STORE_ID || '');
const POLAR_ACCESS_TOKEN = String(process.env.POLAR_ACCESS_TOKEN || '');
const POLAR_ORGANIZATION_ID = String(process.env.POLAR_ORGANIZATION_ID || '');
const PAYHIP_PRODUCT_SECRET_KEY = String(process.env.PAYHIP_PRODUCT_SECRET_KEY || '');
const APP_TOKEN = String(process.env.APP_TOKEN || '');
const COOLDOWN_HOURS = Number(process.env.LICENSE_COOLDOWN_HOURS || 24);
const DATA_FILE = process.env.DATA_FILE || './data/licenses.json';
const LS_API = 'https://api.lemonsqueezy.com/v1/licenses';
const POLAR_API = 'https://api.polar.sh/v1/license-keys';
const PAYHIP_API = 'https://payhip.com/api/v2/license';

function nowIso() {
  return new Date().toISOString();
}

function msUntilCooldown(lastSwitchAt) {
  if (!lastSwitchAt) return 0;
  const next = new Date(lastSwitchAt).getTime() + COOLDOWN_HOURS * 3600 * 1000;
  return Math.max(0, next - Date.now());
}

async function readDb() {
  try {
    const raw = await fs.readFile(DATA_FILE, 'utf8');
    return JSON.parse(raw);
  } catch {
    return { licenses: {} };
  }
}

async function writeDb(db) {
  await fs.mkdir(path.dirname(DATA_FILE), { recursive: true });
  await fs.writeFile(DATA_FILE, JSON.stringify(db, null, 2), 'utf8');
}

async function lsRequest(endpoint, params) {
  if (!API_KEY) throw new Error('Missing LEMON_SQUEEZY_API_KEY');
  const body = new URLSearchParams(params);
  const res = await fetch(`${LS_API}/${endpoint}`, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded',
      Authorization: `Bearer ${API_KEY}`,
    },
    body,
  });
  const data = await res.json();
  if (!res.ok) {
    const message = data?.error || `Lemon Squeezy error (${res.status})`;
    throw new Error(message);
  }
  return data;
}

async function polarRequest(endpoint, payload) {
  if (!POLAR_ACCESS_TOKEN) throw new Error('Missing POLAR_ACCESS_TOKEN');
  if (!POLAR_ORGANIZATION_ID) throw new Error('Missing POLAR_ORGANIZATION_ID');
  const res = await fetch(`${POLAR_API}/${endpoint}`, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      Authorization: `Bearer ${POLAR_ACCESS_TOKEN}`,
    },
    body: JSON.stringify({
      ...payload,
      organization_id: POLAR_ORGANIZATION_ID,
    }),
  });
  const data = await res.json();
  if (!res.ok) {
    const message = data?.detail || data?.error || `Polar error (${res.status})`;
    throw new Error(message);
  }
  return data;
}

async function payhipVerify(licenseKey) {
  if (!PAYHIP_PRODUCT_SECRET_KEY) throw new Error('Missing PAYHIP_PRODUCT_SECRET_KEY');
  const url = new URL(`${PAYHIP_API}/verify`);
  url.searchParams.set('license_key', licenseKey);
  const res = await fetch(url.toString(), {
    method: 'GET',
    headers: {
      Accept: 'application/json',
      'product-secret-key': PAYHIP_PRODUCT_SECRET_KEY,
    },
  });
  // Payhip can return empty body on failure.
  const raw = await res.text();
  if (!res.ok) throw new Error(`Payhip verify failed (${res.status})`);
  if (!raw || !raw.trim()) return null;
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return null;
  }
  return parsed?.data || null;
}

function requireFields(obj, fields) {
  for (const f of fields) {
    if (!obj?.[f]) return f;
  }
  return null;
}

app.get('/health', (_req, res) => {
  res.json({ ok: true, ts: nowIso() });
});

function requireAppToken(req, res) {
  if (!APP_TOKEN) return true;
  const incoming = req.headers['x-app-token'];
  if (incoming !== APP_TOKEN) {
    res.status(401).json({ error: 'Unauthorized client' });
    return false;
  }
  return true;
}

app.post('/license/activate', async (req, res) => {
  if (!requireAppToken(req, res)) return;
  try {
    const missing = requireFields(req.body, ['licenseKey', 'deviceId']);
    if (missing) return res.status(422).json({ error: `Missing field: ${missing}` });

    const { licenseKey, deviceId, instanceName = 'Oracle Mobile' } = req.body;
    const db = await readDb();
    const row = db.licenses[licenseKey] || null;

    if (row && row.currentDeviceId && row.currentDeviceId !== deviceId) {
      const remaining = msUntilCooldown(row.lastSwitchAt);
      if (remaining > 0) {
        return res.status(429).json({
          error: 'Cooldown active',
          code: 'COOLDOWN_ACTIVE',
          retryInSeconds: Math.ceil(remaining / 1000),
        });
      }

      if (row.instanceId && LICENSE_PROVIDER === 'lemonsqueezy') {
        try {
          await lsRequest('deactivate', {
            license_key: licenseKey,
            instance_id: row.instanceId,
          });
        } catch {
          // Best effort: if old instance is already invalid, continue.
        }
      }
    }

    let status = 'active';
    let instanceId = null;
    let instanceNameOut = `${instanceName}:${deviceId}`;

    if (LICENSE_PROVIDER === 'payhip') {
      const verified = await payhipVerify(licenseKey);
      if (!verified || !verified.enabled) {
        return res.status(403).json({ error: 'Invalid or disabled Payhip license key' });
      }
      status = 'active';
      instanceId = null;
      instanceNameOut = `${instanceName}:${deviceId}`;
    } else if (LICENSE_PROVIDER === 'polar') {
      const activation = await polarRequest('activate', {
        key: licenseKey,
        label: `${instanceName}:${deviceId}`,
      });
      status = activation?.status || 'active';
      instanceId = activation?.activation?.id || null;
      instanceNameOut = activation?.activation?.label || instanceNameOut;
      if (status === 'revoked' || status === 'disabled') {
        return res.status(403).json({ error: `License status is ${status}` });
      }
    } else {
      const activation = await lsRequest('activate', {
        license_key: licenseKey,
        instance_name: `${instanceName}:${deviceId}`,
      });
      const license = activation.license_key || {};
      if (STORE_ID && String(license.store_id || '') !== STORE_ID) {
        return res.status(403).json({ error: 'License belongs to a different store' });
      }
      if (license.status === 'disabled' || license.status === 'expired') {
        return res.status(403).json({ error: `License status is ${license.status}` });
      }
      status = license.status;
      instanceId = activation.instance?.id || null;
      instanceNameOut = activation.instance?.name || instanceNameOut;
    }

    db.licenses[licenseKey] = {
      licenseKey,
      currentDeviceId: deviceId,
      instanceId,
      instanceName: instanceNameOut,
      status,
      lastSwitchAt: row?.currentDeviceId && row.currentDeviceId !== deviceId ? nowIso() : row?.lastSwitchAt || nowIso(),
      lastValidatedAt: nowIso(),
      updatedAt: nowIso(),
    };
    await writeDb(db);

    res.json({
      ok: true,
      status,
      currentDeviceId: deviceId,
      cooldownHours: COOLDOWN_HOURS,
      provider: LICENSE_PROVIDER,
    });
  } catch (err) {
    res.status(400).json({ error: String(err.message || err) });
  }
});

app.post('/license/validate', async (req, res) => {
  if (!requireAppToken(req, res)) return;
  try {
    const missing = requireFields(req.body, ['licenseKey', 'deviceId']);
    if (missing) return res.status(422).json({ error: `Missing field: ${missing}` });

    const { licenseKey, deviceId } = req.body;
    const db = await readDb();
    const row = db.licenses[licenseKey];
    if (!row) {
      return res.status(404).json({ error: 'License not activated on this server yet' });
    }

    if (row.currentDeviceId !== deviceId) {
      return res.status(403).json({
        error: 'License currently assigned to another device',
        code: 'DEVICE_MISMATCH',
      });
    }

    let status = row.status || 'active';
    if (LICENSE_PROVIDER === 'payhip') {
      const verified = await payhipVerify(licenseKey);
      status = verified?.enabled ? 'active' : 'disabled';
    } else if (LICENSE_PROVIDER === 'polar') {
      const validation = await polarRequest('validate', {
        key: licenseKey,
        activation_id: row.instanceId || undefined,
      });
      status = validation?.status || status;
    } else {
      const validation = await lsRequest('validate', { license_key: licenseKey });
      const license = validation.license_key || {};
      status = license.status || status;
    }

    if (status === 'expired' || status === 'disabled' || status === 'revoked') {
      row.status = status;
      row.lastValidatedAt = nowIso();
      row.updatedAt = nowIso();
      await writeDb(db);
      return res.status(403).json({ error: `License status is ${status}`, code: 'LICENSE_INACTIVE' });
    }

    row.status = status;
    row.lastValidatedAt = nowIso();
    row.updatedAt = nowIso();
    await writeDb(db);

    res.json({
      ok: true,
      valid: true,
      status,
      currentDeviceId: row.currentDeviceId,
      provider: LICENSE_PROVIDER,
    });
  } catch (err) {
    res.status(400).json({ error: String(err.message || err) });
  }
});

app.listen(PORT, () => {
  console.log(`License server listening on :${PORT}`);
});
