import { ConfigService } from '@nestjs/config';
export interface FirebaseIdentity {
    uid: string;
    phone: string;
}
export declare class FirebaseAdminService {
    private readonly logger;
    private readonly app;
    constructor(config: ConfigService);
    verify(idToken: string): Promise<FirebaseIdentity>;
}
