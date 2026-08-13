"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.RequiresFeature = exports.FEATURE_KEY = void 0;
const common_1 = require("@nestjs/common");
exports.FEATURE_KEY = 'feature';
const RequiresFeature = (key) => (0, common_1.SetMetadata)(exports.FEATURE_KEY, key);
exports.RequiresFeature = RequiresFeature;
//# sourceMappingURL=feature.decorator.js.map