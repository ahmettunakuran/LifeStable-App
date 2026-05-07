import { https } from "firebase-functions/v1";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { faqChunks } from "./faq_data";

const EMBEDDING_MODEL = "text-embedding-004";
const COLLECTION = "doc_embeddings";

/**
 * HTTP trigger that seeds the Firestore doc_embeddings collection with FAQ
 * chunks embedded via Gemini text-embedding-004.
 *
 * Call once after deployment:
 *   curl -X POST https://<region>-<project>.cloudfunctions.net/seedKnowledgeBase \
 *     -H "Authorization: Bearer <ID_TOKEN>" \
 *     -H "x-seed-secret: <value-of-admin.seed_secret config>"
 *
 * Set config values before deploying:
 *   firebase functions:config:set gemini.api_key="AIza..."
 *   firebase functions:config:set admin.seed_secret="your-strong-secret"
 *
 * The function is idempotent: existing documents are skipped unless
 * the query parameter ?force=true is passed to re-embed everything.
 */
export const seedKnowledgeBase = https.onRequest(async (req, res) => {
  // ── Auth guard ──────────────────────────────────────────────────────────
  const seedSecret = process.env.SEED_SECRET;
  const providedSecret = req.headers["x-seed-secret"];
  if (seedSecret && providedSecret !== seedSecret) {
    res.status(403).json({ error: "Forbidden: invalid seed secret" });
    return;
  }

  // ── Gemini API key from environment variable ────────────────────────────
  const geminiApiKey = process.env.GEMINI_API_KEY ?? "";
  if (!geminiApiKey) {
    res.status(500).json({
      error: "GEMINI_API_KEY not set. Add it to functions/.env and redeploy.",
    });
    return;
  }

  const db = admin.firestore();
  const force = req.query["force"] === "true";
  let seeded = 0;
  let skipped = 0;
  const errors: string[] = [];

  for (const chunk of faqChunks) {
    const docRef = db.collection(COLLECTION).doc(chunk.title_type);

    // Skip if already seeded (unless ?force=true)
    if (!force) {
      const existing = await docRef.get();
      if (existing.exists) {
        skipped++;
        continue;
      }
    }

    try {
      const embedding = await generateEmbedding(chunk.content, geminiApiKey);

      await docRef.set({
        content: chunk.content,
        doc_type: chunk.doc_type,
        source_key: chunk.source_key,
        embedding_vector: embedding,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        indexes: chunk.indexes,
        title_type: chunk.title_type,
      });

      seeded++;
      logger.info(`Seeded: ${chunk.title_type}`);

      // Respect Gemini free-tier rate limit (~1 req/s for embedding)
      await sleep(1100);
    } catch (err) {
      const msg = `Failed to seed ${chunk.title_type}: ${err}`;
      logger.error(msg);
      errors.push(msg);
    }
  }

  res.json({
    seeded,
    skipped,
    errors,
    total: faqChunks.length,
  });
});

// ── Helpers ─────────────────────────────────────────────────────────────────

async function generateEmbedding(text: string, apiKey: string): Promise<number[]> {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/` +
    `${EMBEDDING_MODEL}:embedContent?key=${apiKey}`;

  const body = {
    model: `models/${EMBEDDING_MODEL}`,
    content: { parts: [{ text }] },
  };

  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Embedding API ${response.status}: ${errText}`);
  }

  const data = (await response.json()) as { embedding: { values: number[] } };
  return data.embedding.values;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
