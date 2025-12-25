import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { User } from './schemas/user.schema';
import { CreateUserDto } from './dto/create-user.dto';

@Injectable()
export class UsersService {
  [x: string]: any;
  constructor(@InjectModel(User.name) private userModel: Model<User>) { }

  async create(createUserDto: CreateUserDto) {
    const newUser = new this.userModel(createUserDto);
    const savedUser = await newUser.save();

    return {
      success: true,
      message: 'تم التسجيل بنجاح',
      _id: savedUser._id.toString(),
      fullName: savedUser.fullName
    };
  }


  async findAll(): Promise<User[]> {
    return this.userModel.find().exec();
  }
  async remove(id: string) {
    await this.userModel.findByIdAndDelete(id);
    return {
      success: true,
      message: 'تم الحذف بنجاح',
    };
  }
}