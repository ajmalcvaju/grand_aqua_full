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
  Res,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { QuotationsService } from './quotations.service';
import { QuotationStatus, DiscountApprovalStatus, UserRoleType } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { AuthGuard } from '@nestjs/passport';
import { Response } from 'express';

@ApiTags('Quotations & Commercial Approvals')
@Controller('quotations')
export class QuotationsController {
  constructor(private quotationsService: QuotationsService) {}

  private sanitizeQuotation(q: any) {
    if (!q) return q;
    const { profit, profitMargin, totalPurchaseCost, ...safe } = q;
    if (Array.isArray(safe.items)) {
      safe.items = safe.items.map((it: any) => {
        const { purchasePrice, ...safeItem } = it;
        if (safeItem.product) {
          const { purchasePrice: _p, ...safeProd } = safeItem.product;
          if (safeProd.pricing) {
            const { purchasePrice: _pr, ...safePricing } = safeProd.pricing;
            safeProd.pricing = safePricing;
          }
          safeItem.product = safeProd;
        }
        return safeItem;
      });
    }
    return safe;
  }

  @Get()
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List quotations with filters' })
  @ApiQuery({ name: 'buyerProfileId', required: false })
  @ApiQuery({ name: 'salesmanProfileId', required: false })
  @ApiQuery({ name: 'status', enum: QuotationStatus, required: false })
  @ApiQuery({ name: 'discountApprovalStatus', enum: DiscountApprovalStatus, required: false })
  @ApiQuery({ name: 'page', required: false })
  @ApiQuery({ name: 'limit', required: false })
  async findAll(@Query() query: any, @Req() req: any) {
    if (req.user.role === UserRoleType.SALESMAN) {
      const salesman = await (this.quotationsService as any).prisma.salesmanProfile.findUnique({
        where: { userId: req.user.id },
      });
      if (salesman) query.salesmanProfileId = salesman.id;
    } else if (req.user.role === UserRoleType.BUYER) {
      const buyer = await (this.quotationsService as any).prisma.buyerProfile.findUnique({
        where: { userId: req.user.id },
      });
      if (buyer) query.buyerProfileId = buyer.id;
    }
    const result = await this.quotationsService.findAll(query);
    if (req.user.role !== UserRoleType.SUPER_ADMIN && result?.quotations) {
      result.quotations = result.quotations.map((q: any) => this.sanitizeQuotation(q));
    }
    return result;
  }

  @Get(':id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get quotation details and items' })
  async findOne(@Param('id') id: string, @Req() req: any) {
    const quotation = await this.quotationsService.findOne(id);
    if (req.user?.role !== UserRoleType.SUPER_ADMIN) {
      return this.sanitizeQuotation(quotation);
    }
    return quotation;
  }

  @Get(':id/pdf')
  @ApiOperation({ summary: 'Download or preview official Grand Aqua Quotation PDF' })
  async downloadPdf(@Param('id') id: string, @Query('template') template: string, @Res() res: Response) {
    const buffer = await this.quotationsService.getPdfBuffer(id, template);
    res.set({
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename=GrandAqua-Quotation-${id}.pdf`,
      'Content-Length': buffer.length,
    });
    res.end(buffer);
  }

  @Post()
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create new quotation (Super Admin, Salesman, or Buyer Cart Request)' })
  async create(@Body() body: any, @Req() req: any) {
    let buyerProfileId = body.buyerProfileId;
    if (req.user.role === UserRoleType.BUYER || !buyerProfileId) {
      const buyer = await (this.quotationsService as any).prisma.buyerProfile.findUnique({
        where: { userId: req.user.id },
      });
      if (buyer) {
        buyerProfileId = buyer.id;
      }
    }
    return this.quotationsService.create({
      ...body,
      buyerProfileId,
      creatorUser: { id: req.user.id, role: req.user.role },
    });
  }

  @Put(':id/review-discount')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @ApiBearerAuth()
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.SALES_MANAGER)
  @ApiOperation({ summary: 'Approve, reject, or revise requested discount' })
  async reviewDiscount(
    @Param('id') id: string,
    @Body() body: { action: 'APPROVE' | 'REJECT' | 'REVISE'; notes?: string; revisedDiscount?: number },
    @Req() req: any,
  ) {
    return this.quotationsService.reviewDiscount(
      id,
      body.action,
      req.user.id,
      body.notes,
      body.revisedDiscount,
    );
  }

  @Put(':id')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @ApiBearerAuth()
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.SALES_MANAGER, UserRoleType.SALESMAN, UserRoleType.BUYER)
  @ApiOperation({ summary: 'Update quotation items, terms, discount, or salesman' })
  async update(@Param('id') id: string, @Body() body: any, @Req() req: any) {
    return this.quotationsService.update(id, body, { id: req.user.id, role: req.user.role });
  }

  @Put(':id/status')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @ApiBearerAuth()
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.SALES_MANAGER)
  @ApiOperation({ summary: 'Transition quotation status directly (e.g. ACCEPTED, ISSUED, DRAFT, CANCELLED)' })
  async updateStatus(
    @Param('id') id: string,
    @Body() body: { status: QuotationStatus; reason?: string },
    @Req() req: any,
  ) {
    return this.quotationsService.updateStatus(id, body.status, req.user.id, body.reason);
  }

  @Delete(':id')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @ApiBearerAuth()
  @Roles(UserRoleType.SUPER_ADMIN)
  @ApiOperation({ summary: 'Delete quotation and associated records' })
  async delete(@Param('id') id: string) {
    return this.quotationsService.delete(id);
  }

  @Put(':id/buyer-response')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Buyer accepts or rejects quotation' })
  async buyerRespond(
    @Param('id') id: string,
    @Body() body: { response: 'ACCEPT' | 'REJECT' },
    @Req() req: any,
  ) {
    return this.quotationsService.buyerRespond(id, body.response, req.user.id);
  }

  @Post(':id/convert-to-order')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Convert accepted quotation into official Order' })
  async convertToOrder(@Param('id') id: string, @Req() req: any) {
    return this.quotationsService.convertToOrder(id, req.user.id);
  }
}
