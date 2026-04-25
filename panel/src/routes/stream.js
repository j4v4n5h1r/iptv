/**
 * Stream proxy — transcodes MP2 audio to AAC using FFmpeg.
 * GET /stream?url=<encoded_stream_url>
 * GET /stream/hls?url=<encoded_stream_url>  (HLS playlist passthrough with segment rewrite)
 */
const express = require('express');
const { spawn } = require('child_process');
const router = express.Router();

// Active FFmpeg processes — keyed by res to allow cleanup on disconnect
const _active = new WeakMap();

function startFFmpeg(url, res) {
  // -re: read at native frame rate (live streams)
  // -i: input url
  // -c:v copy: pass video through unchanged
  // -c:a aac: transcode audio to AAC
  // -b:a 192k: audio bitrate
  // -ar 48000: sample rate Android prefers
  // -f mpegts: output as MPEG-TS
  // pipe:1: write to stdout
  const ff = spawn('ffmpeg', [
    '-re',
    '-i', url,
    '-c:v', 'copy',
    '-c:a', 'aac',
    '-b:a', '192k',
    '-ar', '48000',
    '-f', 'mpegts',
    'pipe:1',
  ], { stdio: ['ignore', 'pipe', 'ignore'] });

  _active.set(res, ff);

  ff.stdout.pipe(res);

  ff.on('error', () => {
    if (!res.headersSent) res.status(500).end();
  });

  ff.on('close', () => {
    if (!res.writableEnded) res.end();
  });

  res.on('close', () => {
    ff.kill('SIGKILL');
  });
}

// GET /stream?url=http%3A%2F%2F...
router.get('/', (req, res) => {
  const url = req.query.url;
  if (!url) return res.status(400).send('url param required');

  // Basic validation — must be http/https
  if (!/^https?:\/\//i.test(url)) return res.status(400).send('Invalid url');

  res.setHeader('Content-Type', 'video/MP2T');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  startFFmpeg(url, res);
});

module.exports = router;
