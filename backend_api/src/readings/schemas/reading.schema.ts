import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

@Schema({ timestamps: true })
export class Reading extends Document {
  @Prop({ required: true }) userId: string;
  @Prop() heartRate: number;
  @Prop() spo2: number;
  @Prop() tempC: number;
  @Prop() tempF: number;
  @Prop() humidity: number;
  @Prop() heatIndex: number;
  @Prop() statusReport: string; 
}
export const ReadingSchema = SchemaFactory.createForClass(Reading);