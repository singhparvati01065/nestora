import { TowerSpecDto } from './create-society.dto';
export declare class UpdateSocietyDto {
    hasTowers?: boolean;
    towers: TowerSpecDto[];
    force?: boolean;
}
