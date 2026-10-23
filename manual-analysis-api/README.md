# PlastiScan AI Analysis API

A standalone Node.js/Express backend providing PlastiScan's AI analysis features using the Groq API (Text + Vision). Built for production deployment as a Render Web Service.

---

## Architecture

```
Flutter Client
  ├──► GET  /health                   (Public health check for Render & monitors)
  ├──► POST /analyze-manual-product   (Text-first manual analysis with Groq openai/gpt-oss-120b)
  └──► POST /analyze-product          (Image-based analysis with Groq qwen/qwen3.8-27b Vision)
```

Both analysis endpoints require a valid Supabase JWT Bearer token in the `Authorization` header. Token authentication is verified server-side with Supabase Auth before processing AI requests.

The Flutter client persists results through `ScanHistoryService` using Supabase client-side RLS policies. This backend performs no direct database writes.

---

## Endpoints

### 1. `GET /health` (and `HEAD /health`)
* **Access:** Public (no authentication required)
* **Response:**
```json
{
  "status": "ok",
  "service": "plastiscan-api"
}
```

### 2. `POST /analyze-manual-product`
* **Access:** Authenticated (`Authorization: Bearer <token>`)
* **Headers:** `Content-Type: application/json`
* **Body:**
```json
{
  "description": "Clear plastic water bottle used for several months",
  "product_name": "Sample Bottle",
  "material": "PET plastic",
  "category": "Bottle",
  "intended_use": "Cold water drinking",
  "food_contact": "Food or drink contact",
  "temperature_exposure": "Room temperature",
  "product_condition": "Minor scratches on surface",
  "additional_notes": "Kept in backpack"
}
```
* **Response (HTTP 200):**
```json
{
  "success": true,
  "provider": "groq",
  "model": "openai/gpt-oss-120b",
  "result": { ... }
}
```

### 3. `POST /analyze-product` (Image Analysis)
* **Access:** Authenticated (`Authorization: Bearer <token>`)
* **Headers:** `Content-Type: application/json`
* **Body Option A (Storage Path):**
```json
{
  "image_path": "<userId>/scan_12345.jpg"
}
```
*Downloads the image from Supabase Storage `scan-images` bucket using the authenticated user's credentials.*
* **Body Option B (Direct Base64):**
```json
{
  "image_base64": "data:image/jpeg;base64,...",
  "mime_type": "image/jpeg"
}
```
* **Response (HTTP 200):**
```json
{
  "success": true,
  "provider": "groq",
  "model": "qwen/qwen3.8-27b",
  "image_path": "<userId>/scan_12345.jpg",
  "result": {
    "product_name": "Clear plastic water bottle",
    "category": "Drinkware / Bottle",
    "material": "Polyethylene terephthalate",
    "polymer_type": "PET",
    "recycling_code": "1",
    "product_relevance": {
      "is_plastic_product": true,
      "status": "SUPPORTED",
      "reason": "Clear polymer consumer beverage container visible in photograph."
    },
    "microplastic_risk": {
      "level": "LOW",
      "confidence": "HIGH",
      "reasoning": "Container is intact with standard commercial polymer finish."
    },
    "release_mechanisms": ["Mechanical wear", "Heat exposure"],
    "evidence_summary": "Visual analysis shows standard PET water bottle form factor.",
    "evidence": {
      "visible_label": "Mineral water label visible",
      "material_marking": "Resin code 1 PET",
      "visual_characteristics": "Transparent bottle with threaded cap"
    },
    "health_environmental_impact": "Standard consumer food-grade polymer.",
    "safer_alternative": "Stainless steel or glass reusable container.",
    "verification_steps": "Inspect the triangular resin code on the container base.",
    "uncertainty": "Photographic inspection cannot detect microscopic particulate shedding.",
    "disclaimer": "Educational AI estimate based on visual analysis, not laboratory testing."
  }
}
```

---

## Render Deployment Guide

### Service Settings
* **Service Type:** Web Service
* **Name:** `plastiscan-api`
* **Environment:** `Node`
* **Root Directory:** `manual-analysis-api` (or empty if repository root contains `package.json`)
* **Build Command:** `npm ci`
* **Start Command:** `npm start` (or `node server.js`)
* **Health Check Path:** `/health`
* **Auto-Deploy:** Yes (on push to `main`)

### Environment Variables
Configure in Render Dashboard > Environment:
* `NODE_ENV`: `production`
* `GROQ_API_KEY`: *(Your Groq API Key from console.groq.com)*
* `SUPABASE_URL`: *(Your Supabase project URL, e.g. https://xyz.supabase.co)*
* `SUPABASE_ANON_KEY`: *(Your Supabase anon/publishable key)*
* `SUPABASE_SERVICE_ROLE_KEY`: *(Optional, for admin storage access fallback)*
* `PORT`: *(Set automatically by Render)*

---

## Local Development & Testing

```bash
# Run tests (runs 87 automated test cases including mocks)
npm test

# Run development server
npm run dev
```
