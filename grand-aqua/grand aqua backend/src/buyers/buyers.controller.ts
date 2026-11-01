import { Controller, Get, Post, Put, Delete, Param, Body, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { BuyersService } from './buyers.service';
import { BuyerType, LoyaltyTierLevel, AccountStatus, UserRoleType } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { AuthGuard } from '@nestjs/passport';

@ApiTags('Buyers Management')
@Controller('buyers')
@UseGuards(AuthGuard('jwt'))
@ApiBearerAuth()
export class BuyersController {
  constructor(private buyersService: BuyersService) {}

  @Get()
  @ApiOperation({ summary: 'List buyers with filtering and pagination' })
  @ApiQuery({ name: 'buyerType', enum: BuyerType, required: false })
  @ApiQuery({ name: 'loyaltyTier', enum: LoyaltyTierLevel, required: false })
  @ApiQuery({ name: 'accountStatus', enum: AccountStatus, required: false })
  @ApiQuery({ name: 'assignedSalesmanId', required: false })
  @ApiQuery({ name: 'search', required: false })
  @ApiQuery({ name: 'page', required: false })
  @ApiQuery({ name: 'limit', required: false })
  async findAll(@Query() query: any, @Req() req: any) {
    // If the authenticated user is a Salesman, restrict results to their assigned buyers
    if (req.user.role === UserRoleType.SALESMAN) {
      const salesman = await (this.buyersService as any).prisma.salesmanProfile.findUnique({
        where: { userId: req.user.id },
      });
      if (salesman) {
        query.assignedSalesmanId = salesman.id;
      }
    }
    return this.buyersService.findAll(query);
  }

  @Post()
  @UseGuards(RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.OPERATIONS_ADMIN)
  @ApiOperation({ summary: 'Create new buyer account with shop/owner media & credit facilities' })
  async create(@Body() body: any, @Req() req: any) {
    return this.buyersService.create(body, req.user?.id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get complete buyer profile including history, products, and balances' })
  async findOne(@Param('id') id: string) {
    return this.buyersService.findOne(id);
  }

  @Put(':id')
  @UseGuards(RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.OPERATIONS_ADMIN)
  @ApiOperation({ summary: 'Update buyer details, owner/shop images, tier, and limits' })
  async update(@Param('id') id: string, @Body() body: any, @Req() req: any) {
    return this.buyersService.update(id, body, req.user?.id);
  }

  @Delete(':id')
  @UseGuards(RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.OPERATIONS_ADMIN)
  @ApiOperation({ summary: 'Delete buyer profile' })
  async remove(@Param('id') id: string, @Req() req: any) {
    return this.buyersService.remove(id, req.user?.id);
  }

  @Put(':id/promote-type')
  @UseGuards(RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.OPERATIONS_ADMIN)
  @ApiOperation({ summary: 'Promote or change buyer type (Customer -> Dealer -> Wholesaler -> Distributor)' })
  async promoteType(
    @Param('id') id: string,
    @Body() body: { newType: BuyerType; reason: string },
    @Req() req: any,
  ) {
    return this.buyersService.promoteOrChangeBuyerType(id, {
      ...body,
      changedByAdminId: req.user.id,
    });
  }

  @Put(':id/loyalty-tier')
  @UseGuards(RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.OPERATIONS_ADMIN)
  @ApiOperation({ summary: 'Update loyalty tier (Diamond, Gold, Platinum, None)' })
  async changeLoyaltyTier(
    @Param('id') id: string,
    @Body() body: { newTier: LoyaltyTierLevel; reason: string; effectiveDate?: Date; expiryDate?: Date },
    @Req() req: any,
  ) {
    return this.buyersService.changeLoyaltyTier(id, {
      ...body,
      changedByAdminId: req.user.id,
    });
  }

  @Put(':id/assign-salesman')
  @UseGuards(RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.SALES_MANAGER)
  @ApiOperation({ summary: 'Assign or reassign salesman to buyer' })
  async assignSalesman(
    @Param('id') id: string,
    @Body() body: { salesmanProfileId: string; reason?: string },
    @Req() req: any,
  ) {
    return this.buyersService.assignSalesman(id, body.salesmanProfileId, req.user.id, body.reason);
  }

  @Put(':id/status')
  @UseGuards(RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.OPERATIONS_ADMIN)
  @ApiOperation({ summary: 'Activate, suspend, or block buyer account' })
  async updateStatus(
    @Param('id') id: string,
    @Body() body: { status: AccountStatus; reason?: string },
    @Req() req: any,
  ) {
    return this.buyersService.updateAccountStatus(id, body.status, req.user.id, body.reason);
  }
}
