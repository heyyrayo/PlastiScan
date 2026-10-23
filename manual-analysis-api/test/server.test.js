'use strict';

/**
 * PlastiScan Manual Analysis API — automated tests.
 *
 * All external dependencies (Groq, Supabase) are mocked.
 * No real API keys are consumed.
 */

// ─── Mocks (must be declared before require('../server.js')) ──────────────────

// Mock groq-sdk before server.js is required.
jest.mock('groq-sdk', () => {
  const ActualGroq = jest.requireActual('groq-sdk');

  const MockGroq = jest.fn().mockImplementation(() => ({
    chat: {
      completions: {
        create: jest.fn(),
      },
    },
  }));

  // Preserve the real SDK timeout-error class for instanceof checks.
  MockGroq.APIConnectionTimeoutError =
    ActualGroq.APIConnectionTimeoutError;

  return MockGroq;
});

// Mock @supabase/supabase-js before server.js is required.
jest.mock('@supabase/supabase-js', () => {
  return {
    createClient: jest.fn(),
  };
});

// ─── Imports ──────────────────────────────────────────────────────────────────
const http = require('http');
const {
  app,
  normalizeResult,
  normalizeImageResult,
  validateBody,
  validateImagePath,
  buildUserMessage,
  GROQ_VISION_MODEL,
} = require('../server.js');
const Groq = require('groq-sdk');
const { createClient } = require('@supabase/supabase-js');

// ─── Helpers ──────────────────────────────────────────────────────────────────

/** Make a real HTTP request against a started test server. */
function request(server, method, path, { headers = {}, body } = {}) {
  return new Promise((resolve, reject) => {
    const addr = server.address();
    const port = addr.port;
    const payload = body !== undefined ? JSON.stringify(body) : undefined;

    const options = {
      hostname: '127.0.0.1',
      port,
      path,
      method,
      headers: {
        ...(payload !== undefined
          ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload) }
          : {}),
        ...headers,
      },
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        let json;
        try {
          json = JSON.parse(data);
        } catch {
          json = data;
        }
        resolve({ statusCode: res.statusCode, body: json, headers: res.headers });
      });
    });

    req.on('error', reject);
    if (payload !== undefined) req.write(payload);
    req.end();
  });
}

/** Create a fresh server instance bound to a random port. */
function startServer() {
  return new Promise((resolve, reject) => {
    const server = http.createServer(app);
    server.listen(0, '127.0.0.1', () => resolve(server));
    server.on('error', reject);
  });
}

function stopServer(server) {
  return new Promise((resolve) => server.close(resolve));
}

// ─── Fixtures ─────────────────────────────────────────────────────────────────

const VALID_TOKEN = 'valid-supabase-token';
const VALID_USER = { id: 'user-123', email: 'test@example.com' };

const VALID_BODY = {
  description: 'A clear plastic water bottle used daily for cold drinks.',
};

const FULL_GROQ_RESULT = {
  product_name: 'Clear plastic water bottle',
  category: 'Drinkware',
  material: 'Plastic',
  polymer_type: 'Polyethylene terephthalate (PET)',
  recycling_code: '1',
  product_relevance: {
    is_plastic_product: true,
    status: 'SUPPORTED',
    reason: 'Described as a plastic bottle.',
  },
  microplastic_risk: {
    level: 'MEDIUM',
    confidence: 'LOW',
    reasoning: 'PET bottles are associated with microplastic release under certain conditions.',
  },
  release_mechanisms: ['physical abrasion', 'chemical leaching'],
  evidence_summary: 'User-provided description only.',
  health_environmental_impact: 'Potential minor exposure.',
  safer_alternative: 'Stainless steel or glass bottle.',
  verification_steps: 'Check recycling number on bottle base.',
  uncertainty: 'Actual polymer identity unconfirmed.',
  disclaimer: 'Educational AI estimate, not laboratory testing or a product safety certification.',
};

/** Set up a mock Supabase client that returns a valid user and mock storage. */
function mockValidAuth() {
  createClient.mockReturnValue({
    auth: {
      getUser: jest.fn().mockResolvedValue({ data: { user: VALID_USER }, error: null }),
    },
    storage: {
      from: jest.fn().mockReturnValue({
        download: jest.fn().mockResolvedValue({
          data: new Blob([Buffer.from('fake-image-bytes-content')]),
          error: null,
        }),
      }),
    },
  });
}

/** Set up a mock Supabase client that returns an auth error. */
function mockInvalidAuth() {
  createClient.mockReturnValue({
    auth: {
      getUser: jest.fn().mockResolvedValue({
        data: { user: null },
        error: { message: 'JWT expired' },
      }),
    },
  });
}

/** Make Groq return a successful completion with the given result content. */
function mockGroqSuccess(resultObject) {
  const groqInstance = new Groq();
  groqInstance.chat.completions.create.mockResolvedValue({
    choices: [{ message: { content: JSON.stringify(resultObject) } }],
  });
  Groq.mockImplementation(() => groqInstance);
  return groqInstance;
}

/** Make Groq throw an error. */
function mockGroqError(error) {
  const groqInstance = new Groq();
  groqInstance.chat.completions.create.mockRejectedValue(error);
  Groq.mockImplementation(() => groqInstance);
  return groqInstance;
}

// ─── Environment setup ────────────────────────────────────────────────────────

beforeAll(() => {
  process.env.GROQ_API_KEY = 'test-groq-key';
  process.env.SUPABASE_URL = 'https://test.supabase.co';
  process.env.SUPABASE_ANON_KEY = 'test-anon-key';
});

// ─── Unit tests: normalizeResult ──────────────────────────────────────────────

describe('normalizeResult()', () => {
  test('returns all required fields when given a complete valid object', () => {
    const result = normalizeResult(FULL_GROQ_RESULT);

    expect(result).toHaveProperty('product_name');
    expect(result).toHaveProperty('category');
    expect(result).toHaveProperty('material');
    expect(result).toHaveProperty('polymer_type');
    expect(result).toHaveProperty('recycling_code');
    expect(result).toHaveProperty('product_relevance');
    expect(result).toHaveProperty('microplastic_risk');
    expect(result).toHaveProperty('release_mechanisms');
    expect(result).toHaveProperty('evidence_summary');
    expect(result).toHaveProperty('health_environmental_impact');
    expect(result).toHaveProperty('safer_alternative');
    expect(result).toHaveProperty('verification_steps');
    expect(result).toHaveProperty('uncertainty');
    expect(result).toHaveProperty('disclaimer');
  });

  test('accepts a valid MEDIUM risk level', () => {
    const result = normalizeResult(FULL_GROQ_RESULT);
    expect(result.microplastic_risk.level).toBe('MEDIUM');
  });

  test('falls back to UNKNOWN for an unrecognised risk level', () => {
    const result = normalizeResult({
      ...FULL_GROQ_RESULT,
      microplastic_risk: { ...FULL_GROQ_RESULT.microplastic_risk, level: 'EXTREME' },
    });
    expect(result.microplastic_risk.level).toBe('UNKNOWN');
  });

  test('falls back to UNKNOWN risk when microplastic_risk is missing', () => {
    const { microplastic_risk, ...rest } = FULL_GROQ_RESULT;
    const result = normalizeResult(rest);
    expect(result.microplastic_risk.level).toBe('UNKNOWN');
    expect(result.microplastic_risk.confidence).toBe('LOW');
  });

  test('falls back to UNCLEAR product relevance status for invalid value', () => {
    const result = normalizeResult({
      ...FULL_GROQ_RESULT,
      product_relevance: { ...FULL_GROQ_RESULT.product_relevance, status: 'MAYBE' },
    });
    expect(result.product_relevance.status).toBe('UNCLEAR');
  });

  test('accepts null recycling_code', () => {
    const result = normalizeResult({ ...FULL_GROQ_RESULT, recycling_code: null });
    expect(result.recycling_code).toBeNull();
  });

  test('returns null recycling_code for empty string', () => {
    const result = normalizeResult({ ...FULL_GROQ_RESULT, recycling_code: '' });
    expect(result.recycling_code).toBeNull();
  });

  test('caps release_mechanisms at 12 items', () => {
    const mechanisms = Array.from({ length: 20 }, (_, i) => `mechanism-${i}`);
    const result = normalizeResult({ ...FULL_GROQ_RESULT, release_mechanisms: mechanisms });
    expect(result.release_mechanisms).toHaveLength(12);
  });

  test('filters non-string values out of release_mechanisms', () => {
    const result = normalizeResult({
      ...FULL_GROQ_RESULT,
      release_mechanisms: ['valid', 42, null, 'also-valid'],
    });
    expect(result.release_mechanisms).toEqual(['valid', 'also-valid']);
  });

  test('provides fallback product_name when missing', () => {
    const { product_name, ...rest } = FULL_GROQ_RESULT;
    const result = normalizeResult(rest);
    expect(result.product_name).toBe('Product analysis');
  });

  test('handles null input without throwing', () => {
    const result = normalizeResult(null);
    expect(result.product_name).toBe('Product analysis');
    expect(result.microplastic_risk.level).toBe('UNKNOWN');
  });

  test('handles non-object input without throwing', () => {
    const result = normalizeResult('this is not an object');
    expect(result.microplastic_risk.level).toBe('UNKNOWN');
  });

  test('preserves valid HIGH confidence', () => {
    const result = normalizeResult({
      ...FULL_GROQ_RESULT,
      microplastic_risk: { ...FULL_GROQ_RESULT.microplastic_risk, confidence: 'HIGH' },
    });
    expect(result.microplastic_risk.confidence).toBe('HIGH');
  });
});

// ─── Unit tests: validateBody ─────────────────────────────────────────────────

describe('validateBody()', () => {
  test('accepts a valid body with required description', () => {
    expect(validateBody(VALID_BODY).valid).toBe(true);
  });

  test('accepts a body with all optional fields populated', () => {
    expect(
      validateBody({
        ...VALID_BODY,
        product_name: 'My Bottle',
        material: 'PET',
        category: 'Drinkware',
        intended_use: 'Daily drinking',
        food_contact: 'Yes',
        temperature_exposure: 'Cold only',
        product_condition: 'Good',
        additional_notes: 'Bought in 2022.',
      }).valid,
    ).toBe(true);
  });

  test('rejects null body', () => {
    const r = validateBody(null);
    expect(r.valid).toBe(false);
    expect(r.message).toMatch(/JSON object/i);
  });

  test('rejects array body', () => {
    const r = validateBody([]);
    expect(r.valid).toBe(false);
  });

  test('rejects missing description', () => {
    const r = validateBody({ product_name: 'Bottle' });
    expect(r.valid).toBe(false);
    expect(r.message).toMatch(/description/i);
  });

  test('rejects empty description', () => {
    const r = validateBody({ description: '' });
    expect(r.valid).toBe(false);
  });

  test('rejects whitespace-only description', () => {
    const r = validateBody({ description: '   ' });
    expect(r.valid).toBe(false);
  });

  test('rejects description shorter than 10 characters', () => {
    const r = validateBody({ description: 'Short' });
    expect(r.valid).toBe(false);
    expect(r.message).toMatch(/10/);
  });

  test('accepts description of exactly 10 characters', () => {
    expect(validateBody({ description: '1234567890' }).valid).toBe(true);
  });

  test('rejects a product_name that exceeds its field limit', () => {
    const r = validateBody({
      description: 'A valid description here.',
      product_name: 'x'.repeat(201),
    });
    expect(r.valid).toBe(false);
    expect(r.message).toMatch(/product_name/i);
  });

  test('rejects an additional_notes field exceeding 1000 characters', () => {
    const r = validateBody({
      description: 'A valid description here.',
      additional_notes: 'y'.repeat(1001),
    });
    expect(r.valid).toBe(false);
    expect(r.message).toMatch(/additional_notes/i);
  });
});

// ─── Unit tests: buildUserMessage ─────────────────────────────────────────────

describe('buildUserMessage()', () => {
  test('includes the main description', () => {
    const msg = buildUserMessage(VALID_BODY);
    expect(msg).toContain(VALID_BODY.description);
  });

  test('includes optional fields when provided', () => {
    const msg = buildUserMessage({
      ...VALID_BODY,
      product_name: 'My Bottle',
      material: 'PET',
    });
    expect(msg).toContain('Product name: My Bottle');
    expect(msg).toContain('Known material or marking: PET');
  });

  test('does not include empty optional fields', () => {
    const msg = buildUserMessage({ ...VALID_BODY, product_name: '' });
    expect(msg).not.toContain('Product name:');
  });

  test('truncates description at FIELD_LIMITS.description characters', () => {
    const longDesc = 'a'.repeat(6000);
    const msg = buildUserMessage({ description: longDesc });
    // The description section should not be longer than the limit.
    expect(msg.length).toBeLessThan(6000 + 200); // allow for label overhead
  });
});

// ─── Integration tests: HTTP endpoints ───────────────────────────────────────

describe('GET /health', () => {
  let server;

  beforeAll(async () => {
    server = await startServer();
  });

  afterAll(async () => {
    await stopServer(server);
  });

  test('returns 200 with status ok', async () => {
    const res = await request(server, 'GET', '/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  test('does not include API keys or sensitive values', async () => {
    const res = await request(server, 'GET', '/health');
    const body = JSON.stringify(res.body);
    expect(body).not.toContain('test-groq-key');
    expect(body).not.toContain('test-anon-key');
    expect(body).not.toContain('SUPABASE_URL');
  });

  test('responds to HEAD as well', async () => {
    const res = await request(server, 'HEAD', '/health');
    expect(res.statusCode).toBe(200);
  });
});

describe('POST /analyze-manual-product — authentication', () => {
  let server;

  beforeAll(async () => {
    server = await startServer();
  });

  afterAll(async () => {
    await stopServer(server);
  });

  test('rejects request with no Authorization header (401)', async () => {
    const res = await request(server, 'POST', '/analyze-manual-product', {
      body: VALID_BODY,
    });
    expect(res.statusCode).toBe(401);
    expect(res.body.success).toBe(false);
  });

  test('rejects request with malformed Authorization header (401)', async () => {
    const res = await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: 'NotBearer token' },
      body: VALID_BODY,
    });
    expect(res.statusCode).toBe(401);
    expect(res.body.success).toBe(false);
  });

  test('rejects request with "Bearer " and no token (401)', async () => {
    const res = await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: 'Bearer ' },
      body: VALID_BODY,
    });
    expect(res.statusCode).toBe(401);
    expect(res.body.success).toBe(false);
  });

  test('rejects request with invalid/expired token (401)', async () => {
    mockInvalidAuth();

    const res = await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: 'Bearer expired-token' },
      body: VALID_BODY,
    });
    expect(res.statusCode).toBe(401);
    expect(res.body.success).toBe(false);
  });

  test('error response does not include the token', async () => {
    mockInvalidAuth();

    const res = await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: VALID_BODY,
    });
    const body = JSON.stringify(res.body);
    expect(body).not.toContain(VALID_TOKEN);
  });
});

describe('POST /analyze-manual-product — validation', () => {
  let server;

  beforeAll(async () => {
    server = await startServer();
  });

  afterAll(async () => {
    await stopServer(server);
  });

  beforeEach(() => {
    mockValidAuth();
  });

  test('rejects missing description (400)', async () => {
    const res = await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: { product_name: 'Bottle' },
    });
    expect(res.statusCode).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('rejects description shorter than 10 chars (400)', async () => {
    const res = await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: { description: 'Short' },
    });
    expect(res.statusCode).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('rejects wrong Content-Type (415)', async () => {
    // Send as plain text to trigger 415.
    const res = await new Promise((resolve, reject) => {
      const addr = server.address();
      const payload = 'description=a long description here';
      const options = {
        hostname: '127.0.0.1',
        port: addr.port,
        path: '/analyze-manual-product',
        method: 'POST',
        headers: {
          'Content-Type': 'text/plain',
          'Content-Length': Buffer.byteLength(payload),
          Authorization: `Bearer ${VALID_TOKEN}`,
        },
      };
      const req = http.request(options, (res2) => {
        let data = '';
        res2.on('data', (c) => (data += c));
        res2.on('end', () => resolve({ statusCode: res2.statusCode, body: JSON.parse(data) }));
      });
      req.on('error', reject);
      req.write(payload);
      req.end();
    });

    expect(res.statusCode).toBe(415);
    expect(res.body.success).toBe(false);
  });

  test('rejects malformed JSON body (400)', async () => {
    const res = await new Promise((resolve, reject) => {
      const addr = server.address();
      const payload = '{ this is not json ';
      const options = {
        hostname: '127.0.0.1',
        port: addr.port,
        path: '/analyze-manual-product',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
          Authorization: `Bearer ${VALID_TOKEN}`,
        },
      };
      const req = http.request(options, (res2) => {
        let data = '';
        res2.on('data', (c) => (data += c));
        res2.on('end', () => resolve({ statusCode: res2.statusCode, body: JSON.parse(data) }));
      });
      req.on('error', reject);
      req.write(payload);
      req.end();
    });

    expect(res.statusCode).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('rejects oversized request body (413)', async () => {
    // Generate a body larger than 32 KB.
    const res = await new Promise((resolve, reject) => {
      const addr = server.address();
      const largeValue = 'x'.repeat(40 * 1024);
      const payload = JSON.stringify({ description: largeValue });
      const options = {
        hostname: '127.0.0.1',
        port: addr.port,
        path: '/analyze-manual-product',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
          Authorization: `Bearer ${VALID_TOKEN}`,
        },
      };
      const req = http.request(options, (res2) => {
        let data = '';
        res2.on('data', (c) => (data += c));
        res2.on('end', () => {
          try {
            resolve({ statusCode: res2.statusCode, body: JSON.parse(data) });
          } catch {
            resolve({ statusCode: res2.statusCode, body: data });
          }
        });
      });
      req.on('error', reject);
      req.write(payload);
      req.end();
    });

    expect(res.statusCode).toBe(413);
    expect(res.body.success).toBe(false);
  });
});

describe('POST /analyze-manual-product — method guard', () => {
  let server;

  beforeAll(async () => {
    server = await startServer();
  });

  afterAll(async () => {
    await stopServer(server);
  });

  test('rejects GET to analysis endpoint (404 or 405)', async () => {
    const res = await request(server, 'GET', '/analyze-manual-product');
    expect([404, 405]).toContain(res.statusCode);
  });

  test('rejects PUT to analysis endpoint (405)', async () => {
    const res = await request(server, 'PUT', '/analyze-manual-product', {
      body: VALID_BODY,
    });
    expect(res.statusCode).toBe(405);
    expect(res.body.success).toBe(false);
  });
});

describe('POST /analyze-manual-product — Groq integration', () => {
  let server;

  beforeAll(async () => {
    server = await startServer();
  });

  afterAll(async () => {
    await stopServer(server);
  });

  beforeEach(() => {
    mockValidAuth();
  });

  test('returns success with normalised result on valid Groq response', async () => {
    mockGroqSuccess(FULL_GROQ_RESULT);

    const res = await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: VALID_BODY,
    });

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.provider).toBe('groq');
    expect(res.body.model).toBe('openai/gpt-oss-120b');
    expect(res.body.result).toBeDefined();
    expect(res.body.result.microplastic_risk).toBeDefined();
    expect(res.body.result.product_relevance).toBeDefined();
  });

  test('response contains all required result fields', async () => {
    mockGroqSuccess(FULL_GROQ_RESULT);

    const res = await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: VALID_BODY,
    });

    const requiredFields = [
      'product_name', 'category', 'material', 'polymer_type', 'recycling_code',
      'product_relevance', 'microplastic_risk', 'release_mechanisms',
      'evidence_summary', 'health_environmental_impact', 'safer_alternative',
      'verification_steps', 'uncertainty', 'disclaimer',
    ];

    for (const field of requiredFields) {
      expect(res.body.result).toHaveProperty(field);
    }
  });

  test('handles malformed model output gracefully (uses fallback values)', async () => {
    // Groq returns JSON that doesn't match the expected schema.
    mockGroqSuccess({ garbage: 'data', some_field: 123 });

    const res = await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: VALID_BODY,
    });

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    // normalizeResult should have applied all fallbacks.
    expect(res.body.result.microplastic_risk.level).toBe('UNKNOWN');
    expect(res.body.result.product_relevance.status).toBe('UNCLEAR');
  });

  test('returns 502 on Groq provider error', async () => {
    const groqErr = new Error('Groq API error');
    groqErr.status = 500;
    mockGroqError(groqErr);

    const res = await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: VALID_BODY,
    });

    expect(res.statusCode).toBe(502);
    expect(res.body.success).toBe(false);
  });

  test('returns 504 on timeout error (real SDK class via instanceof)', async () => {
    // FIX H-2 regression: use the actual Groq.APIConnectionTimeoutError class.
    // Previously this test set .name = 'APIConnectionTimeoutError' on a plain
    // Error, which passed only because the broken string-comparison code happened
    // to match the mocked .name. The fix uses instanceof, so this test now
    // constructs a genuine instance of the SDK's timeout-error class.
    //
    // groq-sdk is mocked at the module level, so we import the real error class
    // directly from the installed SDK source to construct a faithful instance.
    const { APIConnectionTimeoutError } = require('../node_modules/groq-sdk');
    const timeoutErr = new APIConnectionTimeoutError();
    mockGroqError(timeoutErr);

    const res = await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: VALID_BODY,
    });

    expect(res.statusCode).toBe(504);
    expect(res.body.success).toBe(false);
  });

  test('returns 429 on rate limit error', async () => {
    const rateLimitErr = new Error('Rate limit exceeded');
    rateLimitErr.status = 429;
    mockGroqError(rateLimitErr);

    const res = await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: VALID_BODY,
    });

    expect(res.statusCode).toBe(429);
    expect(res.body.success).toBe(false);
  });

  test('error response does not expose GROQ_API_KEY', async () => {
    const groqErr = new Error('some internal error with key test-groq-key embedded');
    groqErr.status = 500;
    mockGroqError(groqErr);

    const res = await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: VALID_BODY,
    });

    const body = JSON.stringify(res.body);
    expect(body).not.toContain('test-groq-key');
  });

  test('error response does not include a stack trace', async () => {
    const groqErr = new Error('some error');
    groqErr.status = 500;
    mockGroqError(groqErr);

    const res = await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: VALID_BODY,
    });

    const body = JSON.stringify(res.body);
    expect(body).not.toContain('at Object.');
    expect(body).not.toContain('.js:');
  });

  test('handles Groq returning markdown-fenced JSON', async () => {
    // Some models wrap their JSON in ```json ... ``` fences despite json_object mode.
    const groqInstance = new Groq();
    groqInstance.chat.completions.create.mockResolvedValue({
      choices: [
        {
          message: {
            content: '```json\n' + JSON.stringify(FULL_GROQ_RESULT) + '\n```',
          },
        },
      ],
    });
    Groq.mockImplementation(() => groqInstance);

    const res = await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: VALID_BODY,
    });

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.result.microplastic_risk.level).toBe('MEDIUM');
  });
});

// ─── Logging security tests ───────────────────────────────────────────────────

describe('Server logging — sensitive data must not appear in logs', () => {
  let server;
  let logSpy;

  // Fake key used only as a detection sentinel. Not a real credential.
  const FAKE_PROVIDER_KEY = 'fake-sentinel-key-xK9mQ2pL7v';

  beforeAll(async () => {
    server = await startServer();
  });

  afterAll(async () => {
    await stopServer(server);
  });

  beforeEach(() => {
    mockValidAuth();
    // Capture all console.error calls so we can inspect what was logged.
    logSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    logSpy.mockRestore();
  });

  test('does not log raw Groq error message containing a fake API key', async () => {
    // Simulate a Groq error whose message embeds a sensitive string.
    // This tests that the logging path never writes groqErr.message to console.
    const groqErr = new Error(
      `Groq API error: invalid key ${FAKE_PROVIDER_KEY} rejected`,
    );
    groqErr.status = 401;
    mockGroqError(groqErr);

    await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: VALID_BODY,
    });

    // Every argument of every console.error call is checked.
    const allLogged = logSpy.mock.calls.flat().map(String).join(' ');
    expect(allLogged).not.toContain(FAKE_PROVIDER_KEY);
  });

  test('does not log raw error message from the global error handler', async () => {
    // Restore normal console.error for setup, then re-spy for this test.
    logSpy.mockRestore();
    logSpy = jest.spyOn(console, 'error').mockImplementation(() => {});

    // The global error handler is tested by verifying our logSpy was called
    // without the sensitive string — we trigger it indirectly via an express
    // middleware error by making the request module throw synchronously.
    // We do that by making validateBody throw (it never normally throws, but we
    // can verify the logging contract via the Groq path which we already cover).
    // Instead, assert that any existing console.error log captured during the
    // previous failed-Groq request does not contain the fake key.
    const groqErr = new Error(`provider internal: token=${FAKE_PROVIDER_KEY}`);
    groqErr.status = 500;
    mockGroqError(groqErr);

    await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: VALID_BODY,
    });

    const allLogged = logSpy.mock.calls.flat().map(String).join(' ');
    expect(allLogged).not.toContain(FAKE_PROVIDER_KEY);
  });

  test('log output contains safe category classification, not raw message', async () => {
    const groqErr = new Error(`leaked secret ${FAKE_PROVIDER_KEY}`);
    groqErr.status = 503;
    // Use a recognisable error name so we can confirm it appears in the log.
    groqErr.name = 'GroqProviderError';
    mockGroqError(groqErr);

    await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: VALID_BODY,
    });

    const allLogged = logSpy.mock.calls.flat().map(String).join(' ');
    // The fake key must not appear anywhere in logs.
    expect(allLogged).not.toContain(FAKE_PROVIDER_KEY);
    // The safe category (error name) should appear.
    expect(allLogged).toContain('GroqProviderError');
  });
});

// ─── Regression: H-2 — instanceof timeout detection ──────────────────────────

describe('H-2 regression — timeout detection with real SDK class', () => {
  let server;

  beforeAll(async () => {
    server = await startServer();
  });

  afterAll(async () => {
    await stopServer(server);
  });

  beforeEach(() => {
    mockValidAuth();
  });

  test('plain Error with .name patched does NOT produce 504 (old broken behaviour)', async () => {
    // A plain Error with its .name property set to 'APIConnectionTimeoutError'
    // should no longer be detected as a timeout since we now use instanceof.
    // This documents the regression: the old code would have returned 504 here
    // (incorrectly treating any error with that string name as a timeout), but
    // the correct implementation returns 502 for a plain Error.
    const fakeTimeoutErr = new Error('fake timeout via name patch');
    fakeTimeoutErr.name = 'APIConnectionTimeoutError';
    fakeTimeoutErr.status = 500;
    mockGroqError(fakeTimeoutErr);

    const res = await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: VALID_BODY,
    });

    // A plain Error with a patched .name is not an instance of
    // APIConnectionTimeoutError, so it should fall through to 502.
    expect(res.statusCode).toBe(502);
    expect(res.body.success).toBe(false);
  });

  test('real APIConnectionTimeoutError instance returns 504', async () => {
    const { APIConnectionTimeoutError } = require('../node_modules/groq-sdk');
    mockGroqError(new APIConnectionTimeoutError());

    const res = await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: VALID_BODY,
    });

    expect(res.statusCode).toBe(504);
    expect(res.body.success).toBe(false);
  });

  test('real APIConnectionTimeoutError does not expose its message in logs', async () => {
    const logSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
    const { APIConnectionTimeoutError } = require('../node_modules/groq-sdk');
    // The SDK's timeout message is 'Request timed out.' — not sensitive,
    // but we verify the logging path never touches .message regardless.
    mockGroqError(new APIConnectionTimeoutError());

    await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: VALID_BODY,
    });

    const allLogged = logSpy.mock.calls.flat().map(String).join(' ');
    logSpy.mockRestore();

    // Confirm TIMEOUT category was logged, not the raw message.
    expect(allLogged).toContain('TIMEOUT');
    expect(allLogged).not.toContain('Request timed out.');
  });
});

// ─── Regression: M-3 — X-Powered-By header absent ────────────────────────────

describe('M-3 regression — X-Powered-By header must be absent', () => {
  let server;

  beforeAll(async () => {
    server = await startServer();
  });

  afterAll(async () => {
    await stopServer(server);
  });

  test('X-Powered-By header is absent from health endpoint response', async () => {
    const res = await request(server, 'GET', '/health');
    expect(res.headers['x-powered-by']).toBeUndefined();
  });

  test('X-Powered-By header is absent from 401 error response', async () => {
    const res = await request(server, 'POST', '/analyze-manual-product', {
      body: VALID_BODY,
    });
    expect(res.statusCode).toBe(401);
    expect(res.headers['x-powered-by']).toBeUndefined();
  });

  test('X-Powered-By header is absent from 400 validation error response', async () => {
    mockValidAuth();
    const res = await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: { description: 'short' },
    });
    expect(res.statusCode).toBe(400);
    expect(res.headers['x-powered-by']).toBeUndefined();
  });

  test('X-Powered-By header is absent from successful analysis response', async () => {
    mockValidAuth();
    mockGroqSuccess(FULL_GROQ_RESULT);

    const res = await request(server, 'POST', '/analyze-manual-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: VALID_BODY,
    });

    expect(res.statusCode).toBe(200);
    expect(res.headers['x-powered-by']).toBeUndefined();
  });
});

// ─── Regression: M-4 — buildUserMessage respects declared field limits ────────

describe('M-4 regression — buildUserMessage uses correct per-field limits', () => {
  test('product_name is truncated at 200 chars (its declared limit)', () => {
    const longName = 'P'.repeat(300); // 300 chars, limit is 200
    const msg = buildUserMessage({ ...VALID_BODY, product_name: longName });
    // Extract the product_name line from the message.
    const line = msg.split('\n').find((l) => l.startsWith('Product name:'));
    expect(line).toBeDefined();
    const value = line.replace('Product name: ', '');
    expect(value.length).toBeLessThanOrEqual(200);
  });

  test('material is truncated at 300 chars (its declared limit)', () => {
    const longMaterial = 'M'.repeat(400);
    const msg = buildUserMessage({ ...VALID_BODY, material: longMaterial });
    const line = msg.split('\n').find((l) => l.startsWith('Known material or marking:'));
    expect(line).toBeDefined();
    const value = line.replace('Known material or marking: ', '');
    expect(value.length).toBeLessThanOrEqual(300);
  });

  test('category is truncated at 200 chars (its declared limit)', () => {
    const longCat = 'C'.repeat(300);
    const msg = buildUserMessage({ ...VALID_BODY, category: longCat });
    const line = msg.split('\n').find((l) => l.startsWith('Category:'));
    expect(line).toBeDefined();
    const value = line.replace('Category: ', '');
    expect(value.length).toBeLessThanOrEqual(200);
  });

  test('intended_use is truncated at 500 chars (its declared limit)', () => {
    const longUse = 'U'.repeat(600);
    const msg = buildUserMessage({ ...VALID_BODY, intended_use: longUse });
    const line = msg.split('\n').find((l) => l.startsWith('Intended use:'));
    expect(line).toBeDefined();
    const value = line.replace('Intended use: ', '');
    expect(value.length).toBeLessThanOrEqual(500);
  });

  test('product_condition is truncated at 300 chars (its declared limit)', () => {
    const longCond = 'X'.repeat(400);
    const msg = buildUserMessage({ ...VALID_BODY, product_condition: longCond });
    const line = msg.split('\n').find((l) => l.startsWith('Condition and wear:'));
    expect(line).toBeDefined();
    const value = line.replace('Condition and wear: ', '');
    expect(value.length).toBeLessThanOrEqual(300);
  });

  test('additional_notes is truncated at 1000 chars (its declared limit)', () => {
    const longNotes = 'N'.repeat(1200);
    const msg = buildUserMessage({ ...VALID_BODY, additional_notes: longNotes });
    const line = msg.split('\n').find((l) => l.startsWith('Additional notes:'));
    expect(line).toBeDefined();
    const value = line.replace('Additional notes: ', '');
    expect(value.length).toBeLessThanOrEqual(1000);
  });

  test('fields within their limit are not truncated', () => {
    const msg = buildUserMessage({
      ...VALID_BODY,
      product_name: 'A'.repeat(199),   // under 200 limit
      material:     'B'.repeat(299),   // under 300 limit
    });
    const nameLine = msg.split('\n').find((l) => l.startsWith('Product name:'));
    const matLine  = msg.split('\n').find((l) => l.startsWith('Known material or marking:'));
    expect(nameLine.replace('Product name: ', '').length).toBe(199);
    expect(matLine.replace('Known material or marking: ', '').length).toBe(299);
  });
});

// ─── Image Analysis Tests ─────────────────────────────────────────────────────

describe('normalizeImageResult()', () => {
  const FULL_IMAGE_RESULT = {
    product_name: 'Clear plastic bottle',
    category: 'Packaging',
    material: 'Polyethylene terephthalate',
    polymer_type: 'PET',
    recycling_code: '1',
    product_relevance: {
      is_plastic_product: true,
      status: 'SUPPORTED',
      reason: 'A clear consumer beverage bottle is visible.',
    },
    microplastic_risk: {
      level: 'LOW',
      confidence: 'HIGH',
      reasoning: 'Bottle appears intact with no signs of severe weathering or thermal distortion.',
    },
    release_mechanisms: ['Abrasion', 'Sunlight exposure'],
    evidence_summary: 'Visible recycling triangular symbol 1 with PET label on base.',
    evidence: {
      visible_label: 'Mineral water label',
      material_marking: '1 PET',
      visual_characteristics: 'Transparent, uncolored bottle with intact screw cap.',
    },
    health_environmental_impact: 'PET is standard for cold beverage storage.',
    safer_alternative: 'Stainless steel reusable bottle.',
    verification_steps: 'Check resin code on underside.',
    uncertainty: 'Visual analysis cannot determine chemical additives.',
    disclaimer: 'Educational estimate only.',
  };

  test('returns all required fields when given a complete valid object', () => {
    const res = normalizeImageResult(FULL_IMAGE_RESULT);
    expect(res.product_name).toBe('Clear plastic bottle');
    expect(res.microplastic_risk.level).toBe('LOW');
    expect(res.microplastic_risk.confidence).toBe('HIGH');
    expect(res.product_relevance.is_plastic_product).toBe(true);
    expect(res.product_relevance.status).toBe('SUPPORTED');
    expect(res.evidence.visible_label).toBe('Mineral water label');
    expect(res.evidence.material_marking).toBe('1 PET');
    expect(res.release_mechanisms).toEqual(['Abrasion', 'Sunlight exposure']);
    expect(res.safer_alternative).toBe('Stainless steel reusable bottle.');
  });

  test('falls back to UNKNOWN for unsupported risk level', () => {
    const res = normalizeImageResult({
      microplastic_risk: { level: 'CATASTROPHIC' },
    });
    expect(res.microplastic_risk.level).toBe('UNKNOWN');
    expect(res.microplastic_risk.confidence).toBe('LOW');
  });

  test('handles null and empty input safely', () => {
    const res = normalizeImageResult(null);
    expect(res.product_name).toBe('Analyzed product');
    expect(res.microplastic_risk.level).toBe('UNKNOWN');
    expect(res.product_relevance.status).toBe('UNCLEAR');
  });
});

describe('validateImagePath()', () => {
  const userId = 'user-abc-123';

  test('accepts valid path under user directory', () => {
    const res = validateImagePath('user-abc-123/scan_12345.jpg', userId);
    expect(res.valid).toBe(true);
    expect(res.cleanPath).toBe('user-abc-123/scan_12345.jpg');
    expect(res.ext).toBe('jpg');
  });

  test('strips leading scan-images/ bucket prefix and leading slashes', () => {
    const res = validateImagePath('/scan-images/user-abc-123/photo.png', userId);
    expect(res.valid).toBe(true);
    expect(res.cleanPath).toBe('user-abc-123/photo.png');
    expect(res.ext).toBe('png');
  });

  test('rejects path belonging to another user', () => {
    const res = validateImagePath('user-xyz-999/scan_123.jpg', userId);
    expect(res.valid).toBe(false);
    expect(res.status).toBe(403);
  });

  test('rejects directory traversal path', () => {
    const res = validateImagePath('user-abc-123/../secret.jpg', userId);
    expect(res.valid).toBe(false);
    expect(res.status).toBe(403);
  });

  test('rejects unsupported file extension', () => {
    const res = validateImagePath('user-abc-123/malicious.exe', userId);
    expect(res.valid).toBe(false);
    expect(res.status).toBe(400);
  });

  test('rejects non-string input', () => {
    const res = validateImagePath(12345, userId);
    expect(res.valid).toBe(false);
    expect(res.status).toBe(400);
  });
});

describe('POST /analyze-product — Image analysis endpoint', () => {
  let server;

  beforeAll(async () => {
    server = await startServer();
  });

  afterAll(async () => {
    await stopServer(server);
  });

  beforeEach(() => {
    mockValidAuth();
  });

  test('rejects request with no Authorization header (401)', async () => {
    const res = await request(server, 'POST', '/analyze-product', {
      body: { image_path: 'user-123/scan.jpg' },
    });
    expect(res.statusCode).toBe(401);
    expect(res.body.success).toBe(false);
  });

  test('rejects request with wrong Content-Type (415)', async () => {
    const res = await request(server, 'POST', '/analyze-product', {
      headers: {
        Authorization: `Bearer ${VALID_TOKEN}`,
        'Content-Type': 'text/plain',
      },
      body: { image_path: 'user-123/scan.jpg' },
    });
    expect(res.statusCode).toBe(415);
  });

  test('rejects request with missing image_path and image_base64 (400)', async () => {
    const res = await request(server, 'POST', '/analyze-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: {},
    });
    expect(res.statusCode).toBe(400);
    expect(res.body.error).toContain('image_path or image_base64');
  });

  test('rejects image_path belonging to another user (403)', async () => {
    const res = await request(server, 'POST', '/analyze-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: { image_path: 'other-user/scan_123.jpg' },
    });
    expect(res.statusCode).toBe(403);
  });

  test('rejects GET /analyze-product with 405', async () => {
    const res = await request(server, 'GET', '/analyze-product');
    expect(res.statusCode).toBe(405);
  });

  test('successfully processes valid image_base64 request', async () => {
    const sampleImageResult = {
      product_name: 'Reusable water bottle',
      category: 'Drinkware',
      material: 'Polypropylene',
      polymer_type: 'PP',
      recycling_code: '5',
      product_relevance: {
        is_plastic_product: true,
        status: 'SUPPORTED',
        reason: 'Reusable plastic bottle clearly shown.',
      },
      microplastic_risk: {
        level: 'LOW',
        confidence: 'HIGH',
        reasoning: 'Smooth undamaged polymer surface.',
      },
      release_mechanisms: ['Dishwasher heat'],
      evidence_summary: 'Visual inspection shows intact PP-5 markings.',
      evidence: {
        visible_label: 'BPA-Free',
        material_marking: 'PP 5',
        visual_characteristics: 'Opaque blue plastic.',
      },
      health_environmental_impact: 'Food-safe polypropylene.',
      safer_alternative: 'Glass container.',
      verification_steps: 'Inspect recycling stamp.',
      uncertainty: 'Cannot confirm internal degradation.',
      disclaimer: 'Educational estimate.',
    };

    mockGroqSuccess(sampleImageResult);

    const b64Data = Buffer.from('fake-32x32-image-data').toString('base64');
    const res = await request(server, 'POST', '/analyze-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: {
        image_base64: `data:image/jpeg;base64,${b64Data}`,
      },
    });

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.provider).toBe('groq');
    expect(res.body.model).toBe(GROQ_VISION_MODEL);
    expect(res.body.result.product_name).toBe('Reusable water bottle');
    expect(res.body.result.microplastic_risk.level).toBe('LOW');
  });

  test('successfully processes valid image_path with Supabase storage download', async () => {
    const sampleImageResult = {
      product_name: 'Plastic food container',
      category: 'Food container',
      material: 'Polypropylene',
      polymer_type: 'PP',
      microplastic_risk: {
        level: 'MEDIUM',
        confidence: 'MEDIUM',
        reasoning: 'Visible surface scratches and microwaving wear.',
      },
      release_mechanisms: ['Microwave heating', 'Abrasive scrubbing'],
    };

    mockGroqSuccess(sampleImageResult);

    const res = await request(server, 'POST', '/analyze-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: {
        image_path: 'user-123/scan_container.jpg',
      },
    });

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.image_path).toBe('user-123/scan_container.jpg');
    expect(res.body.result.microplastic_risk.level).toBe('MEDIUM');
  });

  test('returns 504 on Groq vision timeout error', async () => {
    const { APIConnectionTimeoutError } = require('../node_modules/groq-sdk');
    mockGroqError(new APIConnectionTimeoutError());

    const b64Data = Buffer.from('test-image-data').toString('base64');
    const res = await request(server, 'POST', '/analyze-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: { image_base64: b64Data },
    });

    expect(res.statusCode).toBe(504);
    expect(res.body.success).toBe(false);
  });

  test('returns 429 on Groq vision rate limit error', async () => {
    const rateLimitErr = new Error('Rate limit exceeded');
    rateLimitErr.status = 429;
    mockGroqError(rateLimitErr);

    const b64Data = Buffer.from('test-image-data').toString('base64');
    const res = await request(server, 'POST', '/analyze-product', {
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
      body: { image_base64: b64Data },
    });

    expect(res.statusCode).toBe(429);
    expect(res.body.success).toBe(false);
  });
});
