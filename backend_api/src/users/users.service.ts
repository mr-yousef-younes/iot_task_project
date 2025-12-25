import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { User } from './schemas/user.schema';
import { CreateUserDto } from './dto/create-user.dto';

@Injectable()
export class UsersService {
  constructor(@InjectModel(User.name) private userModel: Model<User>) { }

  async createOrLogin(createUserDto: CreateUserDto) {

    let user = await this.userModel.findOne({ email: createUserDto.email }).exec();

    if (user) {
     
      return {
        success: true,
        message: 'تم تسجيل الدخول',
        _id: user._id.toString(),
        fullName: user.fullName,
      };
    }

    user = new this.userModel(createUserDto);
    const savedUser = await user.save();

    return {
      success: true,
      message: 'تم التسجيل بنجاح',
      _id: savedUser._id.toString(),
      fullName: savedUser.fullName,
    };
  }


  async findAll(): Promise<User[]> {
    return this.userModel.find().exec();
  }
  async remove(id: string) {
  try {
    await this.userModel.findByIdAndDelete(id);
    return { success: true, message: 'تم الحذف بنجاح' };
  } catch (e) {
    return { success: false, message: 'حدث خطأ أثناء الحذف', error: e.message };
  }
}

}