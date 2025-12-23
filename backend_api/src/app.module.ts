import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { UsersModule } from './users/users.module';
import { ReadingsModule } from './readings/readings.module';

@Module({
  imports: [
    MongooseModule.forRoot('mongodb://127.0.0.1:27017/iot_pulse'),
    UsersModule,
    ReadingsModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule { }
