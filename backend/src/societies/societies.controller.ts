import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { Role } from '@prisma/client';
import { AuthUser, CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { resolveSocietyId } from '../common/society-scope';
import { CreateSocietyDto } from './dto/create-society.dto';
import { UpdateSocietyDto } from './dto/update-society.dto';
import { UpdateSocietyProfileDto } from './dto/update-society-profile.dto';
import { SocietiesService } from './societies.service';

@Controller('societies')
export class SocietiesController {
  constructor(private societies: SocietiesService) {}

  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateSocietyDto) {
    return this.societies.create(user, dto);
  }

  /// Name, address and logo. Separate from the structure PATCH below so a
  /// rename never risks the flat-deletion path.
  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Patch(':id/profile')
  updateProfile(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateSocietyProfileDto,
  ) {
    return this.societies.updateProfile(user, id, dto);
  }

  /// Rewrites the tower/flat structure. Responds 409 with an impact report if
  /// the change would delete flats that still have data; resend with
  /// `force: true` to accept that loss.
  @Roles(Role.SOCIETY_ADMIN, Role.SUPER_ADMIN)
  @Patch(':id')
  update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateSocietyDto,
  ) {
    return this.societies.update(user, id, dto);
  }

  /// The current user's society (or ?societyId=… for a super admin).
  @Get('mine')
  mine(@CurrentUser() user: AuthUser, @Query('societyId') societyId?: string) {
    return this.societies.findOne(resolveSocietyId(user, societyId));
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.societies.findOne(id);
  }

  @Get(':id/flats')
  flats(@Param('id') id: string) {
    return this.societies.flats(id);
  }
}
