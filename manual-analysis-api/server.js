'use strict';

// ─── Dependencies ────────────────────────────────────────────────────────────
const express = require('express');
const Groq = require('groq-sdk');
const { createClient } = require('@supabase/supabase-js');

// ─── Environment & Constants ──────────────────────────────────────────────────
const PORT = parseInt(process.env.PORT, 10) || 3000;

// Text model: openai/gpt-oss-120b on Groq
const GROQ_TEXT_MODEL = 'openai/gpt-oss-120b';
// Legacy constant name preserved for tests expecting GROQ_MODEL
const GROQ_MODEL = GROQ_TEXT_MODEL;

// Vision model: qwen/qwen3.8-27b on Groq (confirmed vision support with JSON mode)
const GROQ_VISION_MODEL = 'qwen/qwen3.8-27b';

// Maximum request body size for JSON payloads (15 MB to accommodate base64 image data)
const MAX_BODY_BYTES = '15mb';

// Maximum image byte size (10 MB binary)
const MAX_IMAGE_BYTES = 10 * 1024 * 1024;

// Allowed image MIME types and extensions
const ALLOWED_IMAGE_EXTENSIONS = ['jpg', 'jpeg', 'png', 'webp'];
const ALLOWED_IMAGE_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

// Per-field character limits for manual analysis (applied after trim).
const FIELD_LIMITS = {
  description: 5000,
  product_name: 200,
  material: 300,
  category: 200,
  intended_use: 500,
  food_contact: 300,
  temperature_exposure: 300,
  product_condition: 300,
  additional_notes: 1000,
};

// Timeout for Groq API requests (milliseconds).
const GROQ_TIMEOUT_MS = 55_000;

// Read secrets lazily at request time
function getConfig() {
  return {
    groqApiKey: process.env.GROQ_API_KEY || '',
    supabaseUrl: process.env.SUPABASE_URL || '',
    supabaseAnonKey: process.env.SUPABASE_ANON_KEY || '',
    supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || '',
  };
}

// ─── Groq client ─────────────────────────────────────────────────────────────
let _groqClient = null;
let _groqClientKey = null;

function getGroqClient() {
  const key = process.env.GROQ_API_KEY || '';
  if (process.env.NODE_ENV === 'test') {
    return new Groq({ apiKey: key, maxRetries: 0 });
  }
  if (!_groqClient || _groqClientKey !== key) {
    _groqClient = new Groq({ apiKey: key, maxRetries: 0 });
    _groqClientKey = key;
  }
  return _groqClient;
}

// ─── Prompts ──────────────────────────────────────────────────────────────────
const SYSTEM_PROMPT = `
You are PlastiScan, an educational assistant for consumer plastic materials.

Analyze a user's written description of a product. The input is user-provided text,
not laboratory evidence. You must always distinguish between:
1. Details explicitly provided by the user.
2. Reasonable general scientific or material knowledge.
3. Uncertain inferences that require verification.
4. Facts that cannot be established without laboratory testing or physical inspection.

NEVER:
- Pretend you saw an image or physical label.
- Claim laboratory testing occurred.
- Invent a recycling code, polymer identity, manufacturer, chemical formula, microplastic
  count, exposure dose, or confirmed safety result.
- Diagnose medical conditions.
- Claim a product is definitively safe based only on its written description.
- Treat missing information as evidence of low risk.
- Use a description alone to establish exact polymer chemistry or quantify microplastic release.
- Present an unsupported qualitative risk estimate as a measured scientific result.

If evidence is insufficient for a risk determination, use "UNKNOWN" risk and "LOW" confidence.
Use LOW, MEDIUM, or HIGH risk only as a cautious qualitative educational estimate with clear
reasoning that acknowledges limitations. Offer practical verification steps (check manufacturer
markings, recycling symbols, food-contact certifications, or obtain laboratory testing).

Return ONLY a valid JSON object with this exact structure and no other text:
{
  "product_name": "string — name or description inferred from input",
  "category": "string — product category",
  "material": "string — known or suspected bulk material",
  "polymer_type": "string — polymer type if identifiable, otherwise Unknown",
  "recycling_code": null or "string — recycling code if clearly indicated",
  "product_relevance": {
    "is_plastic_product": true or false,
    "status": "SUPPORTED" or "UNSUPPORTED" or "UNCLEAR",
    "reason": "string — explanation"
  },
  "microplastic_risk": {
    "level": "LOW" or "MEDIUM" or "HIGH" or "UNKNOWN",
    "confidence": "LOW" or "MEDIUM" or "HIGH",
    "reasoning": "string — educational explanation with acknowledged uncertainty"
  },
  "release_mechanisms": ["array", "of", "strings"],
  "evidence_summary": "string — what evidence was available and what was inferred",
  "health_environmental_impact": "string — general context, not a diagnosis",
  "safer_alternative": "string — practical alternatives if applicable",
  "verification_steps": "string — steps to verify composition and safety",
  "uncertainty": "string — explicit statement of what cannot be established from text",
  "disclaimer": "Educational AI estimate, not laboratory testing or a product safety certification."
}

All fields must be present. Never omit a field. Never invent facts to fill a field — use
"Unknown" or an appropriate fallback string for fields that cannot be populated.
`.trim();

const IMAGE_SYSTEM_PROMPT = `
You are PlastiScan, an educational AI analysis engine for consumer plastic and polymer products.

Analyze the supplied product image.

Important scientific limitation:
The photograph cannot directly detect or prove microplastics, cannot replace laboratory testing, and cannot reliably prove exact polymer chemistry unless meaningful visual evidence (such as recycling codes or resin identification stamps) is present.

Supported examples:
- plastic bottles
- food containers and packaging
- household plastic products
- synthetic textiles and clothing
- consumer polymer goods

Unrelated images such as scenery, pets, screenshots, documents, people, or unrelated non-products must be marked with is_plastic_product = false and status = UNSUPPORTED.

Rules:
- If the image is a relevant plastic product: is_plastic_product = true, status = SUPPORTED.
- If the image may be relevant but visual evidence is weak, blurry, or incomplete: status = UNCLEAR, risk level = UNKNOWN, confidence = LOW.
- If the image is unrelated or unusable: is_plastic_product = false, status = UNSUPPORTED, risk level = UNKNOWN.
- NEVER invent recycling codes, exact polymer chemistry, manufacturer names, microplastic counts, exposure values, or safety certifications.
- Risk must be educational and based only on visible clues and plausible wear/heat/friction/abrasion release mechanisms.

Return ONLY a valid JSON object matching this structure exactly:
{
  "product_name": "string — product name or description",
  "category": "string — product category",
  "material": "string — known or suspected bulk material",
  "polymer_type": "string — polymer type if identifiable, otherwise Unknown",
  "recycling_code": null or "string — recycling code if clearly indicated",
  "product_relevance": {
    "is_plastic_product": true or false,
    "status": "SUPPORTED" or "UNSUPPORTED" or "UNCLEAR",
    "reason": "string — explanation"
  },
  "microplastic_risk": {
    "level": "LOW" or "MEDIUM" or "HIGH" or "UNKNOWN",
    "confidence": "LOW" or "MEDIUM" or "HIGH",
    "reasoning": "string — educational explanation with acknowledged uncertainty"
  },
  "release_mechanisms": ["array", "of", "strings"],
  "evidence_summary": "string — what evidence was observed visually",
  "evidence": {
    "visible_label": "string — label text or Not clearly visible",
    "material_marking": "string — recycling stamp or Not clearly visible",
    "visual_characteristics": "string — texture, color, wear, degradation"
  },
  "health_environmental_impact": "string — educational context, not a diagnosis",
  "safer_alternative": "string — practical reusable or safer alternative",
  "verification_steps": "string — practical verification steps for the consumer",
  "uncertainty": "string — explicit statement of visual analysis limitations",
  "disclaimer": "Educational AI estimate based on visual analysis, not laboratory testing."
}
`.trim();

// ─── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Trims a value to a string, capping at maxLength characters.
 * Returns an empty string for non-string input.
 */
function str(value, maxLength = 2000) {
  if (typeof value !== 'string') return '';
  return value.trim().slice(0, maxLength);
}

/**
 * Normalise and validate a raw text-analysis AI response object.
 */
function normalizeResult(raw) {
  const data = raw !== null && typeof raw === 'object' ? raw : {};

  const relevance =
    data.product_relevance !== null && typeof data.product_relevance === 'object'
      ? data.product_relevance
      : {};

  const risk =
    data.microplastic_risk !== null && typeof data.microplastic_risk === 'object'
      ? data.microplastic_risk
      : {};

  const level = str(risk.level, 20).toUpperCase();
  const confidence = str(risk.confidence, 20).toUpperCase();
  const status = str(relevance.status, 30).toUpperCase();
  const recyclingRaw = str(data.recycling_code, 30);

  return {
    product_name: str(data.product_name, 120) || 'Product analysis',
    category: str(data.category, 100) || 'Unknown',
    material: str(data.material, 100) || 'Unknown',
    polymer_type: str(data.polymer_type, 100) || 'Unknown',
    recycling_code: recyclingRaw.length > 0 ? recyclingRaw : null,
    product_relevance: {
      is_plastic_product: relevance.is_plastic_product === true,
      status: ['SUPPORTED', 'UNSUPPORTED', 'UNCLEAR'].includes(status) ? status : 'UNCLEAR',
      reason:
        str(relevance.reason, 1200) ||
        'The provided description is insufficient to verify product relevance.',
    },
    microplastic_risk: {
      level: ['LOW', 'MEDIUM', 'HIGH'].includes(level) ? level : 'UNKNOWN',
      confidence: ['LOW', 'MEDIUM', 'HIGH'].includes(confidence) ? confidence : 'LOW',
      reasoning:
        str(risk.reasoning, 2000) ||
        'There is insufficient reliable information to assess risk.',
    },
    release_mechanisms: Array.isArray(data.release_mechanisms)
      ? data.release_mechanisms
          .filter((x) => typeof x === 'string')
          .map((x) => x.trim())
          .filter((x) => x.length > 0)
          .slice(0, 12)
      : [],
    evidence_summary:
      str(data.evidence_summary, 1800) ||
      'Based only on the user\u2019s written description; no image or laboratory evidence was analysed.',
    health_environmental_impact:
      str(data.health_environmental_impact, 2000) ||
      'No specific health or environmental conclusion can be verified from the available details.',
    safer_alternative:
      str(data.safer_alternative, 1200) ||
      'Choose products intended for your specific use and follow their manufacturer instructions.',
    verification_steps:
      str(data.verification_steps, 1800) ||
      'Check product markings and manufacturer documentation; laboratory testing may be needed to confirm composition.',
    uncertainty:
      str(data.uncertainty, 1800) ||
      'The product\u2019s composition and actual microplastic release cannot be confirmed from text alone.',
    disclaimer:
      str(data.disclaimer, 500) ||
      'Educational AI estimate, not laboratory testing or a product safety certification.',
  };
}

/**
 * Normalise and validate a raw image-analysis AI response object.
 */
function normalizeImageResult(raw) {
  const data = raw !== null && typeof raw === 'object' ? raw : {};

  const relevance =
    data.product_relevance !== null && typeof data.product_relevance === 'object'
      ? data.product_relevance
      : {};

  const risk =
    data.microplastic_risk !== null && typeof data.microplastic_risk === 'object'
      ? data.microplastic_risk
      : {};

  const evidence =
    data.evidence !== null && typeof data.evidence === 'object'
      ? data.evidence
      : {};

  const level = str(risk.level, 20).toUpperCase();
  const confidence = str(risk.confidence, 20).toUpperCase();
  const status = str(relevance.status, 30).toUpperCase();
  const recyclingRaw = str(data.recycling_code, 30);

  return {
    product_name: str(data.product_name, 120) || 'Analyzed product',
    category: str(data.category, 100) || 'Unknown',
    material: str(data.material, 100) || 'Unknown',
    polymer_type: str(data.polymer_type, 100) || 'Unknown',
    recycling_code: recyclingRaw.length > 0 ? recyclingRaw : null,
    product_relevance: {
      is_plastic_product: relevance.is_plastic_product === true,
      status: ['SUPPORTED', 'UNSUPPORTED', 'UNCLEAR'].includes(status) ? status : 'UNCLEAR',
      reason:
        str(relevance.reason, 1200) ||
        'The provided image does not provide enough reliable evidence.',
    },
    microplastic_risk: {
      level: ['LOW', 'MEDIUM', 'HIGH'].includes(level) ? level : 'UNKNOWN',
      confidence: ['LOW', 'MEDIUM', 'HIGH'].includes(confidence) ? confidence : 'LOW',
      reasoning:
        str(risk.reasoning, 2000) ||
        'The visual evidence is insufficient for a reliable microplastic risk assessment.',
    },
    release_mechanisms: Array.isArray(data.release_mechanisms)
      ? data.release_mechanisms
          .filter((x) => typeof x === 'string')
          .map((x) => x.trim())
          .filter((x) => x.length > 0)
          .slice(0, 12)
      : [],
    evidence_summary:
      str(data.evidence_summary, 1800) ||
      'Based on AI visual analysis of the product photograph. No laboratory testing was performed.',
    evidence: {
      visible_label: str(evidence.visible_label, 500) || 'Not clearly visible.',
      material_marking: str(evidence.material_marking, 500) || 'Not clearly visible.',
      visual_characteristics: str(evidence.visual_characteristics, 1000) || 'Visual characteristics noted.',
    },
    health_environmental_impact:
      str(data.health_environmental_impact, 2000) ||
      'No specific health or environmental conclusion can be verified from the image alone.',
    safer_alternative:
      str(data.safer_alternative, 1200) ||
      'Consider durable reusable alternatives appropriate for the intended use.',
    verification_steps:
      str(data.verification_steps, 1800) ||
      'Check manufacturer documentation and recycling symbols on the physical product.',
    uncertainty:
      str(data.uncertainty, 1800) ||
      'Image-based analysis cannot confirm laboratory-level polymer composition or directly detect microplastics.',
    disclaimer:
      str(data.disclaimer, 500) ||
      'PlastiScan provides educational image-based estimates and does not replace laboratory testing.',
  };
}

/**
 * Build the user message text from validated request fields.
 */
function buildUserMessage(body) {
  const fields = [
    ['Product name',              body.product_name,         'product_name'],
    ['Known material or marking', body.material,             'material'],
    ['Category',                  body.category,             'category'],
    ['Intended use',              body.intended_use,         'intended_use'],
    ['Food contact',              body.food_contact,         'food_contact'],
    ['Temperature exposure',      body.temperature_exposure, 'temperature_exposure'],
    ['Condition and wear',        body.product_condition,    'product_condition'],
    ['Additional notes',          body.additional_notes,     'additional_notes'],
  ];

  const lines = [
    'Analyse the following user-provided product details.',
    'Treat all details as claims from the user, not verified facts.',
    '',
    'Main description:',
    str(body.description, FIELD_LIMITS.description),
    '',
  ];

  for (const [label, value, key] of fields) {
    const clean = str(value, FIELD_LIMITS[key]);
    if (clean.length > 0) {
      lines.push(`${label}: ${clean}`);
    }
  }

  return lines.join('\n');
}

/**
 * Call the Groq API with text input and return a normalised result object.
 */
async function callGroq(userMessage) {
  const { groqApiKey } = getConfig();
  if (!groqApiKey) {
    const err = new Error('GROQ_API_KEY is not configured.');
    err.code = 'MISSING_API_KEY';
    throw err;
  }
  const groq = getGroqClient();

  const completion = await groq.chat.completions.create(
    {
      model: GROQ_TEXT_MODEL,
      temperature: 0.1,
      max_tokens: 1800,
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: userMessage },
      ],
    },
    {
      timeout: GROQ_TIMEOUT_MS,
    },
  );

  const choices = Array.isArray(completion?.choices) ? completion.choices : [];
  const first = choices[0];
  const content = str(first?.message?.content, 15000);

  if (!content) {
    throw new Error('Groq returned an empty response.');
  }

  const cleaned = content
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/```\s*$/i, '')
    .trim();

  let parsed;
  try {
    parsed = JSON.parse(cleaned);
  } catch {
    throw new Error('Groq returned unparseable JSON.');
  }

  return normalizeResult(parsed);
}

/**
 * Call the Groq API with vision input (image + prompt) and return a normalised result object.
 */
async function callGroqVision(imageBase64, mimeType = 'image/jpeg') {
  const { groqApiKey } = getConfig();
  if (!groqApiKey) {
    const err = new Error('GROQ_API_KEY is not configured.');
    err.code = 'MISSING_API_KEY';
    throw err;
  }
  const groq = getGroqClient();

  const dataUri = `data:${mimeType};base64,${imageBase64}`;

  const completion = await groq.chat.completions.create(
    {
      model: GROQ_VISION_MODEL,
      temperature: 0.1,
      max_tokens: 1800,
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: IMAGE_SYSTEM_PROMPT },
        {
          role: 'user',
          content: [
            {
              type: 'text',
              text: 'Analyze this product image for consumer plastic material identity and potential microplastic risk according to PlastiScan instructions. Return valid JSON only.',
            },
            {
              type: 'image_url',
              image_url: { url: dataUri },
            },
          ],
        },
      ],
    },
    {
      timeout: GROQ_TIMEOUT_MS,
    },
  );

  const choices = Array.isArray(completion?.choices) ? completion.choices : [];
  const first = choices[0];
  const content = str(first?.message?.content, 15000);

  if (!content) {
    throw new Error('Groq returned an empty response.');
  }

  const cleaned = content
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/```\s*$/i, '')
    .trim();

  let parsed;
  try {
    parsed = JSON.parse(cleaned);
  } catch {
    throw new Error('Groq returned unparseable JSON.');
  }

  return normalizeImageResult(parsed);
}

// ─── Authentication ───────────────────────────────────────────────────────────

/**
 * Extract and verify the Supabase Bearer token from the Authorization header.
 * Returns the authenticated user object on success.
 */
async function verifySupabaseToken(authorizationHeader) {
  if (!authorizationHeader || !authorizationHeader.startsWith('Bearer ')) {
    const err = new Error('Missing or malformed Authorization header.');
    err.statusCode = 401;
    throw err;
  }

  const token = authorizationHeader.slice('Bearer '.length).trim();
  if (!token) {
    const err = new Error('Authorization token is empty.');
    err.statusCode = 401;
    throw err;
  }

  const { supabaseUrl, supabaseAnonKey } = getConfig();
  if (!supabaseUrl || !supabaseAnonKey) {
    const err = new Error('Server authentication configuration is incomplete.');
    err.statusCode = 503;
    throw err;
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: { Authorization: `Bearer ${token}` },
    },
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionFromUrl: false,
    },
  });

  const { data, error } = await supabase.auth.getUser(token);

  if (error || !data?.user) {
    const err = new Error('Invalid or expired authentication token.');
    err.statusCode = 401;
    throw err;
  }

  return data.user;
}

// ─── Request validation ───────────────────────────────────────────────────────

/**
 * Validate manual product analysis request body fields.
 */
function validateBody(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    return { valid: false, message: 'Request body must be a JSON object.' };
  }

  const description = str(body.description, FIELD_LIMITS.description + 1);

  if (!description) {
    return { valid: false, message: 'description is required.' };
  }

  if (description.length < 10) {
    return {
      valid: false,
      message: 'description must be at least 10 characters.',
    };
  }

  const overLimit = Object.entries(FIELD_LIMITS)
    .filter(([key, limit]) => {
      if (key === 'description') return false;
      const v = body[key];
      return typeof v === 'string' && v.length > limit;
    })
    .map(([key]) => key);

  if (overLimit.length > 0) {
    return {
      valid: false,
      message: `Field(s) exceed maximum length: ${overLimit.join(', ')}.`,
    };
  }

  return { valid: true };
}

/**
 * Validate image_path parameter and user ownership.
 */
function validateImagePath(rawPath, userId) {
  if (typeof rawPath !== 'string') {
    return { valid: false, status: 400, message: 'image_path must be a string.' };
  }

  const cleanPath = rawPath
    .replace(/\\/g, '/')
    .replace(/^\/+/, '')
    .replace(/^scan-images\//i, '')
    .trim();

  if (!cleanPath) {
    return { valid: false, status: 400, message: 'image_path is required.' };
  }

  // Prevent path traversal
  if (
    cleanPath.includes('//') ||
    cleanPath.split('/').some((seg) => seg === '.' || seg === '..' || seg.trim() === '')
  ) {
    return { valid: false, status: 403, message: 'You are not allowed to access this image.' };
  }

  // Enforce user folder scoping
  if (!cleanPath.startsWith(`${userId}/`)) {
    return { valid: false, status: 403, message: 'You are not allowed to access this image.' };
  }

  const ext = cleanPath.split('.').pop()?.toLowerCase() ?? '';
  if (!ALLOWED_IMAGE_EXTENSIONS.includes(ext)) {
    return { valid: false, status: 400, message: 'Unsupported image file type.' };
  }

  return { valid: true, cleanPath, ext };
}

/**
 * Download image binary from Supabase storage bucket 'scan-images' using user's Bearer token.
 */
async function downloadFromStorage(token, cleanPath) {
  const { supabaseUrl, supabaseAnonKey, supabaseServiceRoleKey } = getConfig();

  // Try user-scoped client first (evaluates RLS on storage.objects)
  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: { Authorization: `Bearer ${token}` },
    },
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionFromUrl: false,
    },
  });

  let downloadResult = await userClient.storage.from('scan-images').download(cleanPath);

  // If download failed and service role key is available on the backend, try with admin client
  if ((downloadResult.error || !downloadResult.data) && supabaseServiceRoleKey) {
    const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });
    downloadResult = await adminClient.storage.from('scan-images').download(cleanPath);
  }

  if (downloadResult.error || !downloadResult.data) {
    const err = new Error('The uploaded scan image could not be found.');
    err.statusCode = 404;
    throw err;
  }

  const blob = downloadResult.data;
  const arrayBuffer = await blob.arrayBuffer();
  const buffer = Buffer.from(arrayBuffer);

  if (buffer.length === 0) {
    const err = new Error('The uploaded image is empty.');
    err.statusCode = 400;
    throw err;
  }

  if (buffer.length > MAX_IMAGE_BYTES) {
    const err = new Error('The image exceeds the maximum allowed size of 10 MB.');
    err.statusCode = 413;
    throw err;
  }

  return buffer;
}

// ─── Express application ──────────────────────────────────────────────────────
const app = express();

app.disable('x-powered-by');

// CORS middleware
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, HEAD');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization, X-PlastiScan-Request-Id',
  );
  if (req.method === 'OPTIONS') {
    return res.sendStatus(204);
  }
  next();
});

// Per-route body parsers with specific limits
const manualBodyParser = express.json({
  limit: 32 * 1024, // 32 KB limit for text-based manual entry
  strict: true,
  type: 'application/json',
});

const imageBodyParser = express.json({
  limit: MAX_BODY_BYTES, // 15 MB limit for image payloads
  strict: true,
  type: 'application/json',
});

// ─── Health endpoint ──────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'plastiscan-api',
  });
});

app.head('/health', (req, res) => {
  res.sendStatus(200);
});

// ─── POST /analyze-manual-product ─────────────────────────────────────────────
app.post('/analyze-manual-product', manualBodyParser, async (req, res) => {
  const contentType = req.headers['content-type'] || '';
  if (!contentType.includes('application/json')) {
    return res.status(415).json({
      success: false,
      error: 'Content-Type must be application/json.',
    });
  }

  let user;
  try {
    user = await verifySupabaseToken(req.headers['authorization']);
  } catch (authErr) {
    console.warn('[auth] Token verification failed:', authErr.message);
    return res.status(authErr.statusCode || 401).json({
      success: false,
      error: authErr.message,
    });
  }

  const validation = validateBody(req.body);
  if (!validation.valid) {
    return res.status(400).json({
      success: false,
      error: validation.message,
    });
  }

  const userMessage = buildUserMessage(req.body);

  let result;
  try {
    result = await callGroq(userMessage);
  } catch (groqErr) {
    const safeCategory =
      groqErr.code === 'MISSING_API_KEY'
        ? 'MISSING_API_KEY'
        : groqErr instanceof Groq.APIConnectionTimeoutError
          ? 'TIMEOUT'
          : groqErr.status === 429
            ? 'RATE_LIMITED'
            : groqErr.name || 'PROVIDER_ERROR';

    console.error(
      '[groq] Text analysis error for user',
      user.id,
      '| category:',
      safeCategory,
      '| httpStatus:',
      groqErr.status ?? 'none',
    );

    if (groqErr.code === 'MISSING_API_KEY') {
      return res.status(503).json({
        success: false,
        error: 'The AI analysis service is not available. Please try again later.',
      });
    }

    if (safeCategory === 'TIMEOUT') {
      return res.status(504).json({
        success: false,
        error: 'The AI analysis request timed out. Please try again.',
      });
    }

    if (groqErr.status === 429) {
      return res.status(429).json({
        success: false,
        error: 'The AI service is temporarily rate-limited. Please try again in a moment.',
      });
    }

    return res.status(502).json({
      success: false,
      error: 'The AI provider could not complete the analysis. Please try again.',
    });
  }

  return res.json({
    success: true,
    provider: 'groq',
    model: GROQ_TEXT_MODEL,
    result,
  });
});

app.all('/analyze-manual-product', (req, res) => {
  res.status(405).json({
    success: false,
    error: 'Method not allowed.',
  });
});

// ─── POST /analyze-product (Image-based analysis) ─────────────────────────────
app.post('/analyze-product', imageBodyParser, async (req, res) => {
  const contentType = req.headers['content-type'] || '';
  if (!contentType.includes('application/json')) {
    return res.status(415).json({
      success: false,
      error: 'Content-Type must be application/json.',
    });
  }

  // 1. Authenticate user
  let user;
  const authHeader = req.headers['authorization'];
  try {
    user = await verifySupabaseToken(authHeader);
  } catch (authErr) {
    console.warn('[auth] Token verification failed:', authErr.message);
    return res.status(authErr.statusCode || 401).json({
      success: false,
      error: authErr.message,
    });
  }

  // 2. Validate request input (either image_path or image_base64)
  const body = req.body || {};
  let imageBase64 = '';
  let mimeType = 'image/jpeg';

  if (body.image_base64 && typeof body.image_base64 === 'string') {
    const rawB64 = body.image_base64.trim();
    if (!rawB64) {
      return res.status(400).json({
        success: false,
        error: 'image_base64 is empty.',
      });
    }

    if (rawB64.startsWith('data:image/png')) {
      mimeType = 'image/png';
    } else if (rawB64.startsWith('data:image/webp')) {
      mimeType = 'image/webp';
    } else if (typeof body.mime_type === 'string' && ALLOWED_IMAGE_MIME_TYPES.includes(body.mime_type)) {
      mimeType = body.mime_type;
    }

    imageBase64 = rawB64.replace(/^data:image\/[a-z]+;base64,/i, '').trim();

    const buffer = Buffer.from(imageBase64, 'base64');
    if (buffer.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Invalid base64 image data.',
      });
    }

    if (buffer.length > MAX_IMAGE_BYTES) {
      return res.status(413).json({
        success: false,
        error: 'The image exceeds the maximum allowed size of 10 MB.',
      });
    }
  } else if (body.image_path) {
    const pathValidation = validateImagePath(body.image_path, user.id);
    if (!pathValidation.valid) {
      return res.status(pathValidation.status).json({
        success: false,
        error: pathValidation.message,
      });
    }

    mimeType =
      pathValidation.ext === 'png'
        ? 'image/png'
        : pathValidation.ext === 'webp'
          ? 'image/webp'
          : 'image/jpeg';

    const token = authHeader.slice('Bearer '.length).trim();
    try {
      const buffer = await downloadFromStorage(token, pathValidation.cleanPath);
      imageBase64 = buffer.toString('base64');
    } catch (downloadErr) {
      return res.status(downloadErr.statusCode || 500).json({
        success: false,
        error: downloadErr.message || 'Could not retrieve the uploaded image.',
      });
    }
  } else {
    return res.status(400).json({
      success: false,
      error: 'Either image_path or image_base64 is required.',
    });
  }

  // 3. Call Groq vision inference
  let result;
  try {
    result = await callGroqVision(imageBase64, mimeType);
  } catch (groqErr) {
    const safeCategory =
      groqErr.code === 'MISSING_API_KEY'
        ? 'MISSING_API_KEY'
        : groqErr instanceof Groq.APIConnectionTimeoutError
          ? 'TIMEOUT'
          : groqErr.status === 429
            ? 'RATE_LIMITED'
            : groqErr.name || 'PROVIDER_ERROR';

    console.error(
      '[groq] Vision analysis error for user',
      user.id,
      '| category:',
      safeCategory,
      '| httpStatus:',
      groqErr.status ?? 'none',
    );

    if (groqErr.code === 'MISSING_API_KEY') {
      return res.status(503).json({
        success: false,
        error: 'The AI analysis service is not available. Please try again later.',
      });
    }

    if (safeCategory === 'TIMEOUT') {
      return res.status(504).json({
        success: false,
        error: 'The AI analysis request timed out. Please try again.',
      });
    }

    if (groqErr.status === 429) {
      return res.status(429).json({
        success: false,
        error: 'The AI service is temporarily rate-limited. Please try again in a moment.',
      });
    }

    return res.status(502).json({
      success: false,
      error: 'The AI provider could not complete the image analysis. Please try again.',
    });
  }

  // 4. Return formatted response expected by Flutter client
  return res.json({
    success: true,
    provider: 'groq',
    model: GROQ_VISION_MODEL,
    image_path: body.image_path || null,
    result,
  });
});

app.all('/analyze-product', (req, res) => {
  res.status(405).json({
    success: false,
    error: 'Method not allowed.',
  });
});

// Handle express.json body-size rejection and JSON parse errors cleanly
app.use((err, req, res, next) => {
  if (err.type === 'entity.too.large' || err.status === 413) {
    return res.status(413).json({
      success: false,
      error: 'Request body exceeds the maximum allowed size.',
    });
  }
  if (
    (err.status === 400 || err.statusCode === 400) &&
    (err.type === 'entity.parse.failed' || err instanceof SyntaxError)
  ) {
    return res.status(400).json({
      success: false,
      error: 'Request body must be valid JSON.',
    });
  }
  next(err);
});

// ─── Global 404 handler ───────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint not found.',
  });
});

// ─── Global error handler ─────────────────────────────────────────────────────
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('[server] Unhandled error | name:', err.name || 'Error', '| status:', err.status ?? 'none');
  res.status(500).json({
    success: false,
    error: 'An unexpected server error occurred.',
  });
});

// ─── Start ────────────────────────────────────────────────────────────────────
if (require.main === module) {
  // Load local .env if present and process.loadEnvFile is available
  if (typeof process.loadEnvFile === 'function') {
    const fs = require('fs');
    const path = require('path');
    const envPath = path.resolve(__dirname, '.env');
    if (fs.existsSync(envPath)) {
      try {
        process.loadEnvFile(envPath);
      } catch (_) {}
    }
  }

  const cfg = getConfig();

  if (!cfg.groqApiKey) console.error('[startup] GROQ_API_KEY is not set. Analysis requests will fail.');
  if (!cfg.supabaseUrl) console.error('[startup] SUPABASE_URL is not set. Authentication will fail.');
  if (!cfg.supabaseAnonKey) console.error('[startup] SUPABASE_ANON_KEY is not set. Authentication will fail.');

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`[server] PlastiScan API listening on port ${PORT}`);
    console.log(`[server] Text model: ${GROQ_TEXT_MODEL}`);
    console.log(`[server] Vision model: ${GROQ_VISION_MODEL}`);
    console.log(`[server] GROQ_API_KEY: ${cfg.groqApiKey ? 'set' : 'MISSING'}`);
    console.log(`[server] SUPABASE_URL: ${cfg.supabaseUrl ? 'set' : 'MISSING'}`);
    console.log(`[server] SUPABASE_ANON_KEY: ${cfg.supabaseAnonKey ? 'set' : 'MISSING'}`);
  });
}

// Export app and pure functions for testing.
module.exports = {
  app,
  normalizeResult,
  normalizeImageResult,
  validateBody,
  validateImagePath,
  buildUserMessage,
  callGroq,
  callGroqVision,
  GROQ_MODEL,
  GROQ_TEXT_MODEL,
  GROQ_VISION_MODEL,
};
