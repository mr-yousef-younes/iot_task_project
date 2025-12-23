import { Controller, Post, Get, Body, Query } from '@nestjs/common';
import { ReadingsService } from './readings.service';
import { CreateReadingDto } from './dto/create-reading.dto';

@Controller('readings')
export class ReadingsController {
  constructor(private readonly readingsService: ReadingsService) {}

  @Post()
  create(@Body() dto: CreateReadingDto) {
    return this.readingsService.create(dto);
  }

  @Get('latest')
  getLatest(@Query('userId') userId: string) {
    return this.readingsService.findLatest(userId);
  }
}