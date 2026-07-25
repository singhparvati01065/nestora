"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const path_1 = require("path");
const common_1 = require("@nestjs/common");
const core_1 = require("@nestjs/core");
const config_1 = require("@nestjs/config");
const app_module_1 = require("./app.module");
const uploads_constants_1 = require("./uploads/uploads.constants");
async function bootstrap() {
    const app = await core_1.NestFactory.create(app_module_1.AppModule);
    app.enableCors();
    app.setGlobalPrefix('api');
    app.useStaticAssets(uploads_constants_1.UPLOADS_DIR, { prefix: uploads_constants_1.UPLOADS_ROUTE });
    app.useGlobalPipes(new common_1.ValidationPipe({
        whitelist: true,
        transform: true,
        forbidNonWhitelisted: true,
    }));
    const port = app.get(config_1.ConfigService).get('PORT') ?? 3000;
    await app.listen(port);
    console.log(`Nestora API running on http://localhost:${port}/api`);
    console.log(`Uploads served from ${(0, path_1.join)(uploads_constants_1.UPLOADS_DIR)}`);
}
bootstrap();
//# sourceMappingURL=main.js.map