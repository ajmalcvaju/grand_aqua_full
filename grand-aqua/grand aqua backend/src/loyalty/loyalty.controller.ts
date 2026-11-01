import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { LoyaltyService } from './loyalty.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  UpdateLoyaltyConfigDto,
  AdjustPointsDto,
  ToggleBuyerLoyaltyDto,
  CreateGiftDto,
  UpdateGiftDto,
  RedeemGiftDto,
  UpdateRedemptionStatusDto,
} from './dto/loyalty.dto';

@ApiTags('Loyalty Points & Gift Rewards')
@Controller('loyalty')
export class LoyaltyController {
  constructor(
    private loyaltyService: LoyaltyService,
    private prisma: PrismaService,
  ) {}

  private async getBuyerProfileId(userId: string): Promise<string> {
    const buyer = await this.prisma.buyerProfile.findUnique({
      where: { userId },
    });
    if (!buyer) throw new NotFoundException('Buyer profile not found for current user');
    return buyer.id;
  }

  // --- Configuration ---

  @Get('config')
  @ApiOperation({ summary: 'Get global loyalty program configuration (% rate, 1pt=1INR, enabled status)' })
  async getConfig() {
    return this.loyaltyService.getConfig();
  }

  @Put('config')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update global loyalty configuration (Super Admin only)' })
  async updateConfig(@Req() req: any, @Body() dto: UpdateLoyaltyConfigDto) {
    if (req.user?.role !== 'SUPER_ADMIN') {
      throw new ForbiddenException('Only Super Admin can update loyalty settings');
    }
    return this.loyaltyService.updateConfig(dto);
  }

  // --- Buyer Accounts & Points Management (Super Admin) ---

  @Get('buyers')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List all buyers with their loyalty point balances and status (Super Admin)' })
  async getAllBuyersLoyalty(@Req() req: any, @Query('search') search?: string) {
    if (req.user?.role !== 'SUPER_ADMIN') {
      throw new ForbiddenException('Only Super Admin can view all buyers loyalty accounts');
    }
    return this.loyaltyService.getAllBuyersLoyalty(search);
  }

  @Put('buyers/:buyerId/toggle-status')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Enable or disable loyalty points for a single buyer (Super Admin)' })
  async toggleBuyerLoyalty(
    @Req() req: any,
    @Param('buyerId') buyerId: string,
    @Body() dto: ToggleBuyerLoyaltyDto,
  ) {
    if (req.user?.role !== 'SUPER_ADMIN') {
      throw new ForbiddenException('Only Super Admin can toggle buyer loyalty status');
    }
    const enabled = dto.enabled !== undefined ? dto.enabled : (dto.loyaltyEnabled !== undefined ? dto.loyaltyEnabled : true);
    return this.loyaltyService.toggleBuyerLoyalty(buyerId, enabled);
  }

  @Put('buyers/:buyerId/toggle-loyalty')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Enable or disable loyalty points for a single buyer (alias)' })
  async toggleBuyerLoyaltyAlias(
    @Req() req: any,
    @Param('buyerId') buyerId: string,
    @Body() dto: ToggleBuyerLoyaltyDto,
  ) {
    if (req.user?.role !== 'SUPER_ADMIN') {
      throw new ForbiddenException('Only Super Admin can toggle buyer loyalty status');
    }
    const enabled = dto.enabled !== undefined ? dto.enabled : (dto.loyaltyEnabled !== undefined ? dto.loyaltyEnabled : true);
    return this.loyaltyService.toggleBuyerLoyalty(buyerId, enabled);
  }

  @Post('buyers/:buyerId/adjust-points')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Manually add or reduce loyalty points for a buyer (Super Admin)' })
  async adjustBuyerPoints(
    @Req() req: any,
    @Param('buyerId') buyerId: string,
    @Body() dto: AdjustPointsDto,
  ) {
    if (req.user?.role !== 'SUPER_ADMIN') {
      throw new ForbiddenException('Only Super Admin can adjust loyalty points');
    }
    return this.loyaltyService.adjustBuyerPoints(buyerId, dto, req.user?.fullName || 'Super Admin');
  }

  @Get('buyers/:buyerId/history')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'View complete loyalty points ledger history for a specific buyer (Super Admin)' })
  async getBuyerPointHistory(@Req() req: any, @Param('buyerId') buyerId: string) {
    if (req.user?.role !== 'SUPER_ADMIN') {
      throw new ForbiddenException('Only Super Admin can view customer point ledgers');
    }
    return this.loyaltyService.getBuyerPointHistory(buyerId);
  }

  // --- Buyer Self-Service ---

  @Get('my-summary')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get current loyalty points balance and summary for logged-in buyer' })
  async getBuyerSummary(@Req() req: any) {
    const buyerProfileId = await this.getBuyerProfileId(req.user.id);
    return this.loyaltyService.getBuyerSummary(buyerProfileId);
  }

  @Get('my-history')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get loyalty points transaction ledger for logged-in buyer' })
  async getMyHistory(@Req() req: any) {
    const buyerProfileId = await this.getBuyerProfileId(req.user.id);
    return this.loyaltyService.getMyHistory(buyerProfileId);
  }

  @Post('redeem-gift')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Redeem an available gift reward using loyalty points (Buyer)' })
  async redeemGift(@Req() req: any, @Body() dto: RedeemGiftDto) {
    const buyerProfileId = await this.getBuyerProfileId(req.user.id);
    return this.loyaltyService.redeemGift(buyerProfileId, dto, req.user?.fullName || 'Buyer');
  }

  @Get('my-redemptions')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get list of gifts redeemed by the logged-in buyer' })
  async getMyRedemptions(@Req() req: any) {
    const buyerProfileId = await this.getBuyerProfileId(req.user.id);
    return this.loyaltyService.getMyRedemptions(buyerProfileId);
  }

  // --- Gift Rewards Catalog (Shared / Admin) ---

  @Get('gifts')
  @ApiOperation({ summary: 'List available gifts in the rewards catalog' })
  async getGifts(@Query('forBuyer') forBuyer?: string) {
    return this.loyaltyService.getGifts(forBuyer === 'true');
  }

  @Post('gifts')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create new gift reward in catalog (Super Admin)' })
  async createGift(@Req() req: any, @Body() dto: CreateGiftDto) {
    if (req.user?.role !== 'SUPER_ADMIN') {
      throw new ForbiddenException('Only Super Admin can manage gift catalog');
    }
    return this.loyaltyService.createGift(dto);
  }

  @Put('gifts/:id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update gift reward (Super Admin)' })
  async updateGift(@Req() req: any, @Param('id') id: string, @Body() dto: UpdateGiftDto) {
    if (req.user?.role !== 'SUPER_ADMIN') {
      throw new ForbiddenException('Only Super Admin can manage gift catalog');
    }
    return this.loyaltyService.updateGift(id, dto);
  }

  @Delete('gifts/:id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete gift reward (Super Admin)' })
  async deleteGift(@Req() req: any, @Param('id') id: string) {
    if (req.user?.role !== 'SUPER_ADMIN') {
      throw new ForbiddenException('Only Super Admin can delete gift rewards');
    }
    return this.loyaltyService.deleteGift(id);
  }

  // --- Gift Redemptions Management (Super Admin) ---

  @Get('redemptions')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'View all buyer gift redemption requests (Super Admin)' })
  async getAllRedemptions(@Req() req: any) {
    if (req.user?.role !== 'SUPER_ADMIN') {
      throw new ForbiddenException('Only Super Admin can view redemption requests');
    }
    return this.loyaltyService.getAllRedemptions();
  }

  @Put('redemptions/:id/status')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update redemption request status or reject and refund points (Super Admin)' })
  async updateRedemptionStatus(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: UpdateRedemptionStatusDto,
  ) {
    if (req.user?.role !== 'SUPER_ADMIN') {
      throw new ForbiddenException('Only Super Admin can update redemption status');
    }
    return this.loyaltyService.updateRedemptionStatus(id, dto);
  }
}
