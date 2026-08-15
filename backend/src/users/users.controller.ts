import { Body, Controller, Delete, Patch } from '@nestjs/common';
import { AuthUser, CurrentUser } from '../auth/decorators/current-user.decorator';
import { UpdateMeDto } from './dto/update-me.dto';
import { UsersService } from './users.service';

@Controller('users')
export class UsersController {
  constructor(private users: UsersService) {}

  /// Updates your own name/photo. Any role may do this for themselves.
  @Patch('me')
  updateMe(@CurrentUser() user: AuthUser, @Body() dto: UpdateMeDto) {
    return this.users.updateMe(user.sub, dto);
  }

  /// Closes your own account. Society admins are refused — see the service.
  @Delete('me')
  deleteMe(@CurrentUser() user: AuthUser) {
    return this.users.deleteMe(user.sub, user.role);
  }
}
