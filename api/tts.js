export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const apiKey = process.env.GOOGLE_TTS_API_KEY;
  if (!apiKey) return res.status(503).json({ error: 'GOOGLE_TTS_API_KEY not configured on Vercel' });

  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body) : (req.body || {});
    const text = String(body.text || '').trim().slice(0, 4500);
    if (!text) return res.status(400).json({ error: 'Empty text' });

    const voiceName = body.voiceName || 'en-IN-Neural2-D';
    const languageCode = voiceName.startsWith('te-') ? 'te-IN' : 'en-IN';
    const speakingRate = Math.min(1.8, Math.max(0.65, Number(body.rate || 0.96)));

    const gResp = await fetch(
      `https://texttospeech.googleapis.com/v1/text:synthesize?key=${encodeURIComponent(apiKey)}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          input: { text },
          voice: { languageCode, name: voiceName },
          audioConfig: {
            audioEncoding: 'MP3',
            speakingRate,
            pitch: 0.0,
            effectsProfileId: ['headphone-class-device']
          }
        })
      }
    );

    if (!gResp.ok) {
      const errText = await gResp.text();
      return res.status(gResp.status).json({ error: errText });
    }
    const data = await gResp.json();
    const audioBuf = Buffer.from(data.audioContent, 'base64');
    res.setHeader('Content-Type', 'audio/mpeg');
    res.setHeader('Cache-Control', 'public, max-age=604800');
    return res.status(200).send(audioBuf);
  } catch (err) {
    return res.status(500).json({ error: String(err.message || err) });
  }
}