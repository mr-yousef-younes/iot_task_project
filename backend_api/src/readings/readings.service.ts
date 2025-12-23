import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Reading } from './schemas/reading.schema';
import { CreateReadingDto } from './dto/create-reading.dto';

@Injectable()
export class ReadingsService {
  constructor(@InjectModel(Reading.name) private readingModel: Model<Reading>) {}

  private calculateHeatIndex(tempC: number, humidity: number): number {
    if (humidity <= 0 || humidity > 100) return tempC;
    const T = (tempC * 9/5) + 32;
    const RH = humidity;

    let hi = 0.5 * (T + 61.0 + ((T - 68.0) * 1.2) + (RH * 0.094));
    if (hi >= 80) {
      hi = -42.379 + 2.04901523*T + 10.14333127*RH - 0.22475541*T*RH
        - 0.00683783*T*T - 0.05481717*RH*RH + 0.00122874*T*T*RH
        + 0.00085282*T*RH*RH - 0.00000199*T*T*RH*RH;
    }
    return (hi - 32) * 5/9;
  }

  async create(dto: CreateReadingDto): Promise<Reading> {
    const alerts: string[] = [];

    if (dto.heartRate > 120) alerts.push('خطر: تسارع شديد في ضربات القلب');
    else if (dto.heartRate > 100) alerts.push('تنبيه: تسارع في ضربات القلب');

    if (dto.spo2 > 0 && dto.spo2 < 92) alerts.push('خطر: نقص حاد في الأكسجين');
    else if (dto.spo2 < 94) alerts.push('تنبيه: انخفاض الأكسجين');

    if (dto.tempC >= 39) alerts.push('خطر: حمى شديدة');
    else if (dto.tempC > 38) alerts.push('تنبيه: ارتفاع درجة الحرارة');

    const heatIndexC = this.calculateHeatIndex(dto.tempC, dto.humidity);
    if (heatIndexC >= 40) alerts.push('خطر: إجهاد حراري');
    else if (heatIndexC > 35) alerts.push('تحذير: حرارة مرتفعة');

    const newReading = new this.readingModel({
      ...dto,
      tempF: (dto.tempC * 9/5) + 32,
      heatIndex: Math.round(heatIndexC * 10) / 10,
      statusReport: alerts.length ? alerts.join(' | ') : 'الحالة مستقرة'
    });

    return newReading.save();
  }

  async findLatest(userId: string) {
    return this.readingModel.findOne({ userId }).sort({ createdAt: -1 }).exec();
  }
}
