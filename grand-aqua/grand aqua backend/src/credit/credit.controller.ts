import { Controller, Get, Post, Put, Param, Body, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CreditService } from './credit.service';
import { UserRoleType } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { AuthGuard } from '@nestjs/passport';

@ApiTags('Credit Management')
@Controller('credit')
@UseGuards(AuthGuard('jwt'))
@ApiBearerAuth()
export class CreditController {
  constructor(private creditService: CreditService) {}

  @Get('accounts')
  @UseGuards(RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.ACCOUNTS_MANAGER)
  @ApiOperation({ summary: 'Get all buyer credit accounts and limits' })
  async findAllAccounts() {
    return this.creditService.findAllAccounts();
  }

  @Get('my-account')
  @ApiOperation({ summary: 'Get logged in buyer credit account and transactions' })
  async getMyAccount(@Req() req: any) {
    const buyer = await (this.creditService as any).prisma.buyerProfile.findUnique({
      where: { userId: req.user.id },
    });
    return this.creditService.getBuyerCredit(buyer.id);
  }

  @Get('buyer/:buyerProfileId')
  @ApiOperation({ summary: 'Get specific buyer credit account' })
  async getBuyerCredit(@Param('buyerProfileId') buyerProfileId: string) {
    return this.creditService.getBuyerCredit(buyerProfileId);
  }

  @Put('buyer/:buyerProfileId/limit')
  @UseGuards(RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.ACCOUNTS_MANAGER)
  @ApiOperation({ summary: 'Set or adjust buyer credit limit with reasons' })
  async setCreditLimit(
    @Param('buyerProfileId') buyerProfileId: string,
    @Body() body: { creditLimit: number; paymentTermsDays?: number; reason: string },
    @Req() req: any,
  ) {
    return this.creditService.setOrUpdateLimit(buyerProfileId, {
      ...body,
      adminId: req.user.id,
    });
  }

  @Post('apply')
  @ApiOperation({ summary: 'Buyer or salesman submits credit facility application' })
  async applyForCredit(
    @Body() body: { buyerProfileId?: string; requestedLimit: number; reason: string },
    @Req() req: any,
  ) {
    let buyerId = body.buyerProfileId;
    if (!buyerId) {
      const buyer = await (this.creditService as any).prisma.buyerProfile.findUnique({
        where: { userId: req.user.id },
      });
      buyerId = buyer?.id;
    }
    return this.creditService.applyForCredit(buyerId, body.requestedLimit, body.reason);
  }
}
