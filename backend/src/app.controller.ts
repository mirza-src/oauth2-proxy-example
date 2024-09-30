import { Controller, Get } from '@nestjs/common';
import { AppService } from './app.service';
import { User, UserEntity } from './decorators/user.decorator';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getHello(@User() user?: UserEntity): string {
    return this.appService.getHello(user.name);
  }
}
