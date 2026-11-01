import { Controller, Get, Post, Body, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { PaymentsService } from './payments.service';
import { PaymentMethod, UserRoleType } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { AuthGuard } from '@nestjs/passport';

@ApiTags('Payments & Receivables')
@Controller('payments')
@UseGuards(AuthGuard('jwt'))
@ApiBearerAuth()
export class PaymentsController {
  constructor(private paymentsService: PaymentsService) {}

  @Get()
  @ApiOperation({ summary: 'Get payment records with filters' })
  @ApiQuery({ name: 'buyerProfileId', required: false })
  @ApiQuery({ name: 'orderId', required: false })
  @ApiQuery({ name: 'paymentMethod', enum: PaymentMethod, required: false })
  @ApiQuery({ name: 'page', required: false })
  @ApiQuery({ name: 'limit', required: false })
  async findAll(@Query() query: any, @Req() req: any) {
    if (req.user.role === UserRoleType.BUYER) {
      const buyer = await (this.paymentsService as any).prisma.buyerProfile.findUnique({
        where: { userId: req.user.id },
      });
      if (buyer) query.buyerProfileId = buyer.id;
    }
    return this.paymentsService.findAll(query);
  }

  @Post()
  @UseGuards(RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.ACCOUNTS_MANAGER, UserRoleType.SALESMAN)
  @ApiOperation({ summary: 'Record payment entry against buyer or order' })
  async recordPayment(@Body() body: any, @Req() req: any) {
    return this.paymentsService.recordPayment(body, req.user.id);
  }

  @Get('receivables-summary')
  @UseGuards(RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.ACCOUNTS_MANAGER)
  @ApiOperation({ summary: 'Get summary of outstanding receivables and debtors' })
  async getReceivablesSummary() {
    return this.paymentsService.getReceivablesSummary();
  }
}
