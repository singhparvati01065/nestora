import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';

/// One tower's per-floor flat counts. `flatsPerFloor[i]` is the flat count on
/// floor i+1; its length is the tower's floor count.
export class TowerSpecDto {
  @IsArray()
  @ArrayMinSize(1)
  @IsInt({ each: true })
  @Min(1, { each: true })
  flatsPerFloor: number[];
}

export class CreateSocietyDto {
  @IsString()
  name: string;

  @IsString()
  address: string;

  @IsOptional()
  @IsString()
  city?: string;

  @IsOptional()
  @IsString()
  state?: string;

  /// False for a society that is one building with no towers. Its flats are
  /// numbered 101, 102 instead of A101, A102, and it must send exactly one
  /// entry in [towers] — the building itself.
  ///
  /// Fixed at creation: changing it later would renumber every flat.
  @IsOptional()
  @IsBoolean()
  hasTowers?: boolean;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => TowerSpecDto)
  towers: TowerSpecDto[];
}
