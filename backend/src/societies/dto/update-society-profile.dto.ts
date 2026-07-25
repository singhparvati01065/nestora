import { IsOptional, IsString, MinLength } from 'class-validator';

/// The society's identity — name, address, logo.
///
/// Deliberately separate from [UpdateSocietyDto], which rewrites towers/flats:
/// renaming a society is harmless, while restructuring it can delete flats and
/// needs the whole confirm-and-force dance. Keeping them apart means a rename
/// can never trip that.
export class UpdateSocietyProfileDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  name?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  address?: string;

  /// A URL from POST /uploads. Send null to drop back to the initial.
  @IsOptional()
  @IsString()
  logoUrl?: string | null;
}
