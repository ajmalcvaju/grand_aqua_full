import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';

@ApiTags('Health')
@Controller()
export class AppController {
  @Get()
  @ApiOperation({ summary: 'Health check endpoint' })
  healthCheck() {
    return {
      status: 'online',
      message: 'Grand Aqua Unified Backend API is active and running',
      timestamp: new Date().toISOString(),
      docs: '/api/v1/docs',
    };
  }
}
