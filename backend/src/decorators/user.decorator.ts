import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export type UserEntity = {
  name: string;
  email: string;
};

export const User = createParamDecorator(
  (_: unknown, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    return request.user as UserEntity;
  },
);
