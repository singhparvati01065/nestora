import { IsArray, IsOptional, IsString, MinLength } from 'class-validator';

/// The bits of your own account you may change. Role, phone and society are
/// deliberately absent — those are not yours to reassign.
export class UpdateMeDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  name?: string;

  /// A URL from POST /uploads. Send null to drop back to the initial.
  @IsOptional()
  @IsString()
  photoUrl?: string | null;

  /// Maintenance trades. Replaces the whole list when sent.
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  trades?: string[];
}
