import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsOptional,
  ValidateNested,
} from 'class-validator';
import { TowerSpecDto } from './create-society.dto';

/// Rewrites a society's tower/flat structure.
///
/// Name and address are deliberately absent — they are not editable here yet.
///
/// The update is a diff, not a rebuild: flats that still exist in the new spec
/// keep their id and everything attached to them. Only flats that fall outside
/// the new spec are removed, and removing one that has residents/bills/etc is
/// refused unless [force] is set.
export class UpdateSocietyDto {
  /// Switches between one building and towers. Omit to keep the current layout.
  ///
  /// Changing it renumbers every flat (A101 ⇄ 101), which the diff sees as
  /// deleting all of them and creating new ones — so it runs straight into the
  /// destructive-change guard below, and needs [force] like any other loss.
  @IsOptional()
  @IsBoolean()
  hasTowers?: boolean;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => TowerSpecDto)
  towers: TowerSpecDto[];

  /// Acknowledges the data loss reported by a previous unforced attempt.
  @IsOptional()
  @IsBoolean()
  force?: boolean;
}
