import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  public isConnected = false;

  async onModuleInit() {
    try {
      await this.$connect();
      this.isConnected = true;
    } catch (err) {
      this.isConnected = false;
      console.warn('Database connection warning (will retry on query):', err?.message || err);
    }
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
