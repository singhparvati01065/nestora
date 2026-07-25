import { randomUUID } from 'crypto';
import { existsSync, mkdirSync } from 'fs';
import { extname } from 'path';
import {
  BadRequestException,
  Controller,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import {
  ALLOWED_MIME,
  MAX_UPLOAD_BYTES,
  UPLOADS_DIR,
  UPLOADS_ROUTE,
} from './uploads.constants';

/// Accepts an image and hands back the URL to store on a user or society.
///
/// Authenticated (the global JWT guard covers it) — uploads are not public.
@Controller('uploads')
export class UploadsController {
  @Post()
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: (_req, _file, cb) => {
          // First upload on a fresh checkout has no folder yet.
          if (!existsSync(UPLOADS_DIR)) mkdirSync(UPLOADS_DIR, { recursive: true });
          cb(null, UPLOADS_DIR);
        },
        filename: (_req, file, cb) => {
          // Never reuse the client's filename: it is attacker-controlled and
          // would allow path traversal and overwriting other users' files.
          const ext = extname(file.originalname).toLowerCase().slice(0, 10);
          cb(null, `${randomUUID()}${ext}`);
        },
      }),
      limits: { fileSize: MAX_UPLOAD_BYTES },
      fileFilter: (_req, file, cb) => {
        if (!ALLOWED_MIME.includes(file.mimetype)) {
          return cb(
            new BadRequestException('Only JPEG, PNG, WebP or HEIC images'),
            false,
          );
        }
        cb(null, true);
      },
    }),
  )
  upload(@UploadedFile() file?: Express.Multer.File) {
    if (!file) throw new BadRequestException('No file uploaded');
    return { url: `${UPLOADS_ROUTE}${file.filename}` };
  }
}
