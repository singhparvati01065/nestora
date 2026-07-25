export declare class TowerSpecDto {
    flatsPerFloor: number[];
}
export declare class CreateSocietyDto {
    name: string;
    address: string;
    hasTowers?: boolean;
    towers: TowerSpecDto[];
}
