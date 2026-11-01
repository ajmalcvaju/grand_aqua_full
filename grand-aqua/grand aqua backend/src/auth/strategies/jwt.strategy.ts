import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../../prisma/prisma.service';

const OBJECT_ID_REGEX = /^[0-9a-fA-F]{24}$/;

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private prisma: PrismaService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: process.env.JWT_SECRET || 'grand_aqua_super_secure_jwt_secret_key_2026_dev_prod',
    });
  }

  async validate(payload: any) {
    if (!payload) {
      throw new UnauthorizedException('Invalid authentication payload');
    }

    let user: any = null;

    // 1. If payload.sub is a valid MongoDB 24-character hexadecimal ObjectId
    if (typeof payload.sub === 'string' && OBJECT_ID_REGEX.test(payload.sub)) {
      try {
        user = await this.prisma.user.findUnique({
          where: { id: payload.sub },
          include: {
            buyerProfile: true,
            salesmanProfile: true,
          },
        });
      } catch (err) {
        // Fallback to email/role lookup below
        user = null;
      }
    }

    // 2. If user wasn't found by sub (or sub was non-hex like 'dev-admin-id'), lookup by email or phone
    if (!user && payload.email) {
      try {
        user = await this.prisma.user.findFirst({
          where: { email: payload.email.toLowerCase() },
          include: {
            buyerProfile: true,
            salesmanProfile: true,
          },
        });
      } catch (err) {
        user = null;
      }
    }

    // 3. Fallback for Super Admin session if dev fallback token was used
    if (!user && (payload.sub === 'dev-admin-id' || payload.email === 'admin@grandaqua.com')) {
      try {
        user = await this.prisma.user.findFirst({
          where: { role: 'SUPER_ADMIN' },
          include: {
            buyerProfile: true,
            salesmanProfile: true,
          },
        });
      } catch (err) {
        user = null;
      }
    }

    if (!user || user.status === 'BLOCKED' || user.status === 'SUSPENDED') {
      throw new UnauthorizedException('User account is invalid, blocked, or session expired. Please sign in again.');
    }

    return user;
  }
}
