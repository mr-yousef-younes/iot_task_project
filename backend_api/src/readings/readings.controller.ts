import { Controller, Get, Post, Body } from '@nestjs/common';
import { ReadingsService } from './readings.service';

@Controller('readings')
export class ReadingsController {
     constructor(private readonly readingsService: ReadingsService) { }

     @Post()
     addReading(@Body('value') value: number) {
          return this.readingsService.create(value);
     }
     @Get('latest')
     getLatest() {
          return this.readingsService.findlatest();
     }
}
