import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { SalesmenService } from './salesmen.service';
import { UserRoleType } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { AuthGuard } from '@nestjs/passport';

@ApiTags('Salesmen & Incentives')
@Controller('salesmen')
@UseGuards(AuthGuard('jwt'))
@ApiBearerAuth()
export class SalesmenController {
  constructor(private salesmenService: SalesmenService) {}

  @Get()
  @ApiOperation({ summary: 'Get all salesmen with metrics and targets' })
  async findAll() {
    return this.salesmenService.findAll();
  }

  @Post()
  @UseGuards(RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.SALES_MANAGER)
  @ApiOperation({ summary: 'Create / Register new sales representative' })
  async create(@Body() body: any) {
    return this.salesmenService.create(body);
  }

  @Get('my-performance')
  @ApiOperation({ summary: 'Get performance dashboard for logged in salesman' })
  async getMyPerformance(@Req() req: any) {
    const salesman = await (this.salesmenService as any).prisma.salesmanProfile.findUnique({
      where: { userId: req.user.id },
    });
    return this.salesmenService.getPerformance(salesman.id);
  }

  @Get('my-incentives')
  @ApiOperation({ summary: 'Get incentive ledger for logged in salesman' })
  async getMyIncentives(@Req() req: any) {
    const salesman = await (this.salesmenService as any).prisma.salesmanProfile.findUnique({
      where: { userId: req.user.id },
    });
    return this.salesmenService.getIncentiveLedger(salesman.id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get salesman detail profile' })
  async findOne(@Param('id') id: string) {
    return this.salesmenService.findOne(id);
  }

  @Put(':id')
  @UseGuards(RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.SALES_MANAGER)
  @ApiOperation({ summary: 'Update salesman profile details' })
  async update(@Param('id') id: string, @Body() body: any) {
    return this.salesmenService.update(id, body);
  }

  @Put(':id/toggle-block')
  @UseGuards(RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN)
  @ApiOperation({ summary: 'Block or unblock salesman access' })
  async toggleBlock(@Param('id') id: string, @Body() body: { reason?: string }) {
    return this.salesmenService.toggleBlock(id, body?.reason);
  }

  @Delete(':id')
  @UseGuards(RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN)
  @ApiOperation({ summary: 'Delete salesman account' })
  async deleteSalesman(@Param('id') id: string) {
    return this.salesmenService.deleteSalesman(id);
  }

  @Get(':id/buyers')
  @ApiOperation({ summary: 'Get buyers assigned to salesman' })
  async getAssignedBuyers(@Param('id') id: string) {
    return this.salesmenService.getAssignedBuyers(id);
  }

  @Post(':id/assign-buyer')
  @UseGuards(RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.SALES_MANAGER)
  @ApiOperation({ summary: 'Assign a buyer to salesman' })
  async assignBuyer(@Param('id') id: string, @Body('buyerProfileId') buyerProfileId: string) {
    return this.salesmenService.assignBuyer(id, buyerProfileId);
  }

  @Delete(':id/unassign-buyer/:buyerId')
  @UseGuards(RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.SALES_MANAGER)
  @ApiOperation({ summary: 'Unassign a buyer from salesman' })
  async unassignBuyer(@Param('id') id: string, @Param('buyerId') buyerId: string) {
    return this.salesmenService.unassignBuyer(id, buyerId);
  }

  @Get(':id/sales-history')
  @ApiOperation({ summary: 'Get salesman sales history filtered by dates and buyer' })
  @ApiQuery({ name: 'startDate', required: false })
  @ApiQuery({ name: 'endDate', required: false })
  @ApiQuery({ name: 'buyerProfileId', required: false })
  @ApiQuery({ name: 'page', required: false })
  @ApiQuery({ name: 'limit', required: false })
  async getSalesHistory(@Param('id') id: string, @Query() query: any) {
    return this.salesmenService.getSalesHistory(id, query);
  }

  @Get(':id/performance')
  @ApiOperation({ summary: 'Get detailed performance analytics for specific salesman' })
  async getPerformance(@Param('id') id: string) {
    return this.salesmenService.getPerformance(id);
  }

  @Put('incentives/:ledgerId/approve')
  @UseGuards(RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.SALES_MANAGER)
  @ApiOperation({ summary: 'Admin approves calculated salesman incentive' })
  async approveIncentive(
    @Param('ledgerId') ledgerId: string,
    @Body() body: { approvedAmount?: number },
    @Req() req: any,
  ) {
    return this.salesmenService.approveIncentive(ledgerId, req.user.id, body.approvedAmount);
  }

  @Put('incentives/:ledgerId/pay')
  @UseGuards(RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.ACCOUNTS_MANAGER)
  @ApiOperation({ summary: 'Record incentive payout to salesman' })
  async markIncentivePaid(@Param('ledgerId') ledgerId: string) {
    return this.salesmenService.markIncentivePaid(ledgerId);
  }
}
