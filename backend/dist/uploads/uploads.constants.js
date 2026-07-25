"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MAX_UPLOAD_BYTES = exports.ALLOWED_MIME = exports.UPLOADS_ROUTE = exports.UPLOADS_DIR = void 0;
const path_1 = require("path");
exports.UPLOADS_DIR = (0, path_1.join)(process.cwd(), 'uploads');
exports.UPLOADS_ROUTE = '/uploads/';
exports.ALLOWED_MIME = [
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
];
exports.MAX_UPLOAD_BYTES = 5 * 1024 * 1024;
//# sourceMappingURL=uploads.constants.js.map