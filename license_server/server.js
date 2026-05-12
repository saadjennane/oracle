import express from 'express';
import fs from 'fs/promises';
import path from 'path';

const app = express();
app.use(express.json());

const PORT = Number(process.env.PORT || 8787);
const API_KEY = process.env.LEMON_SQUEEZY_API_KEY || '';
const STORE_ID = String(process.env.LEMON_SQUEEZY_STORE_ID || '');
const APP_TOKEN = String(process.env.APP_TOKEN || '');
const BETA_MASTER_KEY = String(process.env.BETA_MASTER_KEY || '');
const COOLDOWN_HOURS = Number(process.env.LICENSE_COOLDOWN_HOURS || 24);
const DATA_FILE = process.env.DATA_FILE || './data/licenses.json';
const LS_API = 'https://api.lemonsqueezy.com/v1/licenses';

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

    // Temporary beta bypass key: no activation limit, no cooldown.
    if (BETA_MASTER_KEY && licenseKey === BETA_MASTER_KEY) {
      db.licenses[licenseKey] = {
        licenseKey,
        currentDeviceId: deviceId,
        instanceId: null,
        instanceName: `${instanceName}:${deviceId}`,
        status: 'active',
        isBetaMasterKey: true,
        lastSwitchAt: nowIso(),
        lastValidatedAt: nowIso(),
        updatedAt: nowIso(),
      };
      await writeDb(db);
      return res.json({
        ok: true,
        status: 'active',
        currentDeviceId: deviceId,
        betaBypass: true,
      });
    }

    if (row && row.currentDeviceId && row.currentDeviceId !== deviceId) {
      const remaining = msUntilCooldown(row.lastSwitchAt);
      if (remaining > 0) {
        return res.status(429).json({
          error: 'Cooldown active',
          code: 'COOLDOWN_ACTIVE',
          retryInSeconds: Math.ceil(remaining / 1000),
        });
      }

      if (row.instanceId) {
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

    db.licenses[licenseKey] = {
      licenseKey,
      currentDeviceId: deviceId,
      instanceId: activation.instance?.id || null,
      instanceName: activation.instance?.name || null,
      status: license.status,
      lastSwitchAt: row?.currentDeviceId && row.currentDeviceId !== deviceId ? nowIso() : row?.lastSwitchAt || nowIso(),
      lastValidatedAt: nowIso(),
      updatedAt: nowIso(),
    };
    await writeDb(db);

    res.json({
      ok: true,
      status: license.status,
      currentDeviceId: deviceId,
      cooldownHours: COOLDOWN_HOURS,
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
      if (BETA_MASTER_KEY && licenseKey === BETA_MASTER_KEY) {
        return res.json({
          ok: true,
          valid: true,
          status: 'active',
          currentDeviceId: deviceId,
          betaBypass: true,
        });
      }
      return res.status(404).json({ error: 'License not activated on this server yet' });
    }

    if (row.isBetaMasterKey) {
      row.currentDeviceId = deviceId;
      row.lastValidatedAt = nowIso();
      row.updatedAt = nowIso();
      await writeDb(db);
      return res.json({
        ok: true,
        valid: true,
        status: 'active',
        currentDeviceId: deviceId,
        betaBypass: true,
      });
    }

    if (row.currentDeviceId !== deviceId) {
      return res.status(403).json({
        error: 'License currently assigned to another device',
        code: 'DEVICE_MISMATCH',
      });
    }

    const validation = await lsRequest('validate', { license_key: licenseKey });
    const license = validation.license_key || {};

    if (license.status === 'expired' || license.status === 'disabled') {
      row.status = license.status;
      row.lastValidatedAt = nowIso();
      row.updatedAt = nowIso();
      await writeDb(db);
      return res.status(403).json({ error: `License status is ${license.status}`, code: 'LICENSE_INACTIVE' });
    }

    row.status = license.status;
    row.lastValidatedAt = nowIso();
    row.updatedAt = nowIso();
    await writeDb(db);

    res.json({
      ok: true,
      valid: true,
      status: license.status,
      currentDeviceId: row.currentDeviceId,
    });
  } catch (err) {
    res.status(400).json({ error: String(err.message || err) });
  }
});

app.listen(PORT, () => {
  console.log(`License server listening on :${PORT}`);
});
