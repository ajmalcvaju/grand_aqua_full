import { Controller, Get, Post, Body, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { OffersService } from './offers.service';
import { BuyerType, LoyaltyTierLevel, UserRoleType } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { AuthGuard } from '@nestjs/passport';

@ApiTags('Loyalty, Offers & Vouchers')
@Controller('offers')
export class OffersController {
  constructor(private offersService: OffersService) {}

  @Get('tiers')
  @ApiOperation({ summary: 'Get all loyalty tiers (None, Diamond, Gold, Platinum)' })
  async getTiers() {
    return this.offersService.getAllTiers();
  }

  @Get()
  @ApiOperation({ summary: 'Get all active promotional offers' })
  @ApiQuery({ name: 'buyerType', enum: BuyerType, required: false })
  @ApiQuery({ name: 'loyaltyTier', enum: LoyaltyTierLevel, required: false })
  async getOffers(@Query() query: any) {
    return this.offersService.getAllOffers(query);
  }

  @Get('vouchers')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get available gift vouchers' })
  async getVouchers() {
    return this.offersService.getAllVouchers();
  }

  @Post('vouchers/validate')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Validate voucher code and calculate applicable discount' })
  async validateVoucher(
    @Body() body: { code: string; orderSubtotal: number },
    @Req() req: any,
  ) {
    const buyer = await (this.offersService as any).prisma.buyerProfile.findUnique({
      where: { userId: req.user.id },
    });
    return this.offersService.validateVoucher(body.code, buyer?.id, body.orderSubtotal);
  }

  @Post('vouchers')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.OPERATIONS_ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create new gift voucher' })
  async createVoucher(@Body() body: any) {
    return this.offersService.createVoucher(body);
  }
}
