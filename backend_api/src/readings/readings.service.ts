import { Injectable } from '@nestjs/common';

@Injectable()
export class ReadingsService {
     private readings: any[] = [];
     create(val: number) {
          const data = {
               value: val, data: new Date()
          };
          this.readings.push(data);
          return data;
     }
     findlatest() {
          if (this.readings.length === 0) return { message: 'no data yet' };
          return this.readings[this.readings.length - 1];
     }
}
