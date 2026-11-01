import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { ReportsService } from './reports.service';
import { UserRoleType } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { AuthGuard } from '@nestjs/passport';

@ApiTags('Dashboard & Reports')
@Controller('reports')
@UseGuards(AuthGuard('jwt'), RolesGuard)
@ApiBearerAuth()
export class ReportsController {
  constructor(private reportsService: ReportsService) {}

  @Get('dashboard')
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.OPERATIONS_ADMIN, UserRoleType.SALES_MANAGER)
  @ApiOperation({ summary: 'Get comprehensive Super Admin dashboard metrics and charts' })
  @ApiQuery({ name: 'period', enum: ['today', '7days', 'month', 'lastMonth'], required: false })
  async getDashboard(@Query('period') period?: string) {
    return this.reportsService.getAdminDashboard(period);
  }
}
