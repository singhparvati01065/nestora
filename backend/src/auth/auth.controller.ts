import { Body, Controller, Get, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import { AuthUser, CurrentUser } from './decorators/current-user.decorator';
import { Public } from './decorators/public.decorator';
import {
  DevLoginDto,
  FirebaseLoginDto,
  LoginDto,
  RegisterDto,
} from './dto/auth.dto';

@Controller('auth')
export class AuthController {
  constructor(private auth: AuthService) {}

  @Public()
  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.auth.register(dto);
  }

  @Public()
  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto);
  }

  /// Trades a Firebase phone-OTP ID token for a Nestora JWT. Public because the
  /// Firebase token IS the credential — it is verified before anything else.
  ///
  /// NOTE: like `register` above, this lets a brand-new user name their own
  /// role, so anyone can self-signup as SOCIETY_ADMIN. Fine for dev; a real
  /// deployment wants admin roles granted by invite, not claimed at signup.
  @Public()
  @Post('firebase')
  firebase(@Body() dto: FirebaseLoginDto) {
    return this.auth.firebaseLogin(dto);
  }

  /// ⚠️ TEMPORARY, LOCAL DEV ONLY — signs in as any phone with no verification.
  /// Scaffolding while Firebase phone auth is disabled in the console; the
  /// service refuses unless DEV_LOGIN_ENABLED=true and NODE_ENV != production.
  /// Delete this together with `AuthService.devLogin` once OTP works.
  @Public()
  @Post('dev-login')
  devLogin(@Body() dto: DevLoginDto) {
    return this.auth.devLogin(dto);
  }

  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    return this.auth.me(user.sub);
  }

  /// Hands back a fresh token whose claims match the current DB row. The client
  /// calls this after an action that changes those claims (e.g. creating the
  /// first society) so the in-flight JWT stops being stale.
  @Post('refresh')
  refresh(@CurrentUser() user: AuthUser) {
    return this.auth.refresh(user.sub);
  }
}
