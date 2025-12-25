import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Reading } from './schemas/reading.schema';
import { CreateReadingDto } from './dto/create-reading.dto';

@Injectable()
export class ReadingsService {
  constructor(@InjectModel(Reading.name) private readingModel: Model<Reading>) {}

 
  async create(dto: CreateReadingDto): Promise<{ alerts: string[] }> {
    const alerts: string[] = dto.alerts || [];

    const newReading = new this.readingModel({
      ...dto,
      statusReport: alerts.length ? alerts.join(' | ') : 'الحالة مستقرة'
    });
    await newReading.save();

    return { alerts };
  }

  async findLatest(userId: string) {
    return this.readingModel.findOne({ userId }).sort({ createdAt: -1 }).exec();
  }

  async findAll(userId: string) {
    if (!userId || userId === 'null') return [];
    return this.readingModel.find({ userId }).sort({ createdAt: -1 }).limit(100).exec();
  }
}
