import { join } from 'path';

/// Where uploaded files land on disk. Relative to the process cwd (the backend
/// folder), so it survives `nest build` moving code into dist/.
export const UPLOADS_DIR = join(process.cwd(), 'uploads');

/// The URL prefix they are served under. Static assets bypass the global 'api'
/// prefix, so a stored url looks like `/uploads/ab12.jpg`.
export const UPLOADS_ROUTE = '/uploads/';

/// Only real image types — this endpoint exists for avatars and logos.
export const ALLOWED_MIME = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
];

export const MAX_UPLOAD_BYTES = 5 * 1024 * 1024; // 5 MB
