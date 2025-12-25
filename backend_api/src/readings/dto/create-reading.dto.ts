export class CreateReadingDto {
  userId: string;
  heartRate: number;
  spo2: number;
  tempC: number;
  humidity: number;
  alerts?: string[];
}