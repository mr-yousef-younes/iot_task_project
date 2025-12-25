import { Controller, Post, Get, Body, Delete, Param } from '@nestjs/common';
import { UsersService } from './users.service';
import { CreateUserDto } from './dto/create-user.dto';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) { }

  @Post('signup-or-login')
  async signupOrLogin(@Body() createUserDto: CreateUserDto) {
    return this.usersService.createOrLogin(createUserDto);
  }


  @Get()
  findAll() {
    return this.usersService.findAll();
  }

  @Delete(':id')
  async remove(@Param('id') id: string) {
    try {
      const result = await this.usersService.remove(id);
      return result;
    } catch (e) {
      return { success: false, message: 'حدث خطأ أثناء الحذف', error: e.message };
    }
  }

}