export declare class TowerSpecDto {
    flatsPerFloor: number[];
}
export declare class CreateSocietyDto {
    name: string;
    address: string;
    city?: string;
    state?: string;
    hasTowers?: boolean;
    towers: TowerSpecDto[];
}
