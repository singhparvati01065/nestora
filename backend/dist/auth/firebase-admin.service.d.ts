import { ConfigService } from '@nestjs/config';
export interface FirebaseIdentity {
    uid: string;
    phone: string;
}
export declare class FirebaseAdminService {
    private readonly logger;
    private readonly app;
    private readonly hasCredential;
    constructor(config: ConfigService);
    private readServiceAccount;
    verify(idToken: string): Promise<FirebaseIdentity>;
}
