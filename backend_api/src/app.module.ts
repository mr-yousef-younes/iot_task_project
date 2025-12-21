import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { ReadingsController } from './readings/readings.controller';
import { ReadingsService } from './readings/readings.service';

@Module({
  imports: [],
  controllers: [AppController, ReadingsController],
  providers: [AppService, ReadingsService],
})
export class AppModule {}
