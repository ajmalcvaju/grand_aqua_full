import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class SettingsService {
  constructor(private prisma: PrismaService) {}

  async getAllSettings() {
    const settings = await this.prisma.companySettings.findMany();
    return settings.reduce((acc, curr) => {
      acc[curr.key] = curr.value;
      return acc;
    }, {} as Record<string, string>);
  }

  async updateSetting(key: string, value: string, description?: string) {
    return this.prisma.companySettings.upsert({
      where: { key },
      update: { value, description },
      create: { key, value, description },
    });
  }

  async getAdminStaff() {
    return this.prisma.user.findMany({
      where: {
        role: {
          notIn: ['BUYER', 'SALESMAN'],
        },
      },
      select: {
        id: true,
        fullName: true,
        email: true,
        phone: true,
        role: true,
        status: true,
        createdAt: true,
        lastLoginAt: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getRoles() {
    return this.prisma.adminRole.findMany({
      include: {
        permissions: {
          include: { permission: true },
        },
      },
    });
  }
}
