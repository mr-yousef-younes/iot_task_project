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
async getLatest(@Query('userId') userId: string) {
  const latest = await this.readingsService.findLatest(userId); 
  if (!latest) {
    return { success: true, data: null }; 
  }
  return { success: true, data: latest };
}

  @Get('all')
findAll(@Query('userId') userId: string) {
  return this.readingsService.findAll(userId);
}
}