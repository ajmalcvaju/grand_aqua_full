import {
  Controller,
  Get,
  Post,
  Put,
  Param,
  Body,
  Query,
  UseGuards,
  Req,
  Res,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { OrdersService } from './orders.service';
import { OrderStatus, PaymentStatus, UserRoleType } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { AuthGuard } from '@nestjs/passport';
import { Response } from 'express';

@ApiTags('Orders')
@Controller('orders')
export class OrdersController {
  constructor(private ordersService: OrdersService) {}

  private sanitizeOrder(ord: any) {
    if (!ord) return ord;
    const { profit, profitMargin, totalPurchaseCost, ...safe } = ord;
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
  @ApiOperation({ summary: 'List orders with filters' })
  @ApiQuery({ name: 'status', enum: OrderStatus, required: false })
  @ApiQuery({ name: 'paymentStatus', enum: PaymentStatus, required: false })
  @ApiQuery({ name: 'buyerProfileId', required: false })
  @ApiQuery({ name: 'salesmanProfileId', required: false })
  @ApiQuery({ name: 'search', required: false })
  @ApiQuery({ name: 'page', required: false })
  @ApiQuery({ name: 'limit', required: false })
  async findAll(@Query() query: any, @Req() req: any) {
    if (req.user?.role === UserRoleType.SALESMAN) {
      const salesman = await (this.ordersService as any).prisma.salesmanProfile.findUnique({
        where: { userId: req.user.id },
      });
      if (salesman) query.salesmanProfileId = salesman.id;
    } else if (req.user?.role === UserRoleType.BUYER) {
      const buyer = await (this.ordersService as any).prisma.buyerProfile.findUnique({
        where: { userId: req.user.id },
      });
      if (buyer) query.buyerProfileId = buyer.id;
    }
    const result = await this.ordersService.findAll(query);
    if (req.user?.role !== UserRoleType.SUPER_ADMIN && result?.orders) {
      result.orders = result.orders.map((o: any) => this.sanitizeOrder(o));
    }
    return result;
  }

  @Get('my-orders')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List current buyer purchase orders' })
  async getMyOrders(@Req() req: any, @Query() query: any) {
    const buyer = await (this.ordersService as any).prisma.buyerProfile.findUnique({
      where: { userId: req.user.id },
    });
    const buyerQuery = {
      ...query,
      buyerProfileId: buyer ? buyer.id : req.user.id,
      limit: query?.limit || 100,
    };
    const result = await this.ordersService.findAll(buyerQuery);
    const orders = result?.orders || [];
    return orders.map((o: any) => this.sanitizeOrder(o));
  }

  @Get(':id/invoice-pdf')
  @ApiOperation({ summary: 'Download official GST Tax Invoice as PDF' })
  async downloadInvoicePdf(@Param('id') id: string, @Query('template') template: string, @Res() res: Response) {
    const { buffer, invoiceNumber } = await this.ordersService.getInvoicePdf(id, template);
    res.set({
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename=GrandAqua-Invoice-${invoiceNumber}.pdf`,
      'Content-Length': buffer.length,
    });
    res.end(buffer);
  }

  @Get(':id/invoice/pdf')
  @ApiOperation({ summary: 'Download official GST Tax Invoice as PDF (alias)' })
  async downloadInvoicePdfAlias(@Param('id') id: string, @Query('template') template: string, @Res() res: Response) {
    return this.downloadInvoicePdf(id, template, res);
  }

  @Get(':id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get order details, items, timeline, and payments' })
  async findOne(@Param('id') id: string, @Req() req: any) {
    const order = await this.ordersService.findOne(id);
    if (req.user?.role !== UserRoleType.SUPER_ADMIN) {
      return this.sanitizeOrder(order);
    }
    return order;
  }

  @Post('checkout')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Direct cart checkout for buyers' })
  async directCheckout(@Body() body: any, @Req() req: any) {
    return this.ordersService.createDirectCheckoutOrder(req.user.id, body);
  }

  @Put(':id/dispatch')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.ORDER_MANAGER, UserRoleType.OPERATIONS_ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Dispatch order with carrier tracking and generate GST invoice' })
  async dispatchOrder(
    @Param('id') id: string,
    @Body() body: { trackingNumber: string; carrierName?: string; expectedDeliveryDate?: string; notes?: string },
    @Req() req: any,
  ) {
    return this.ordersService.dispatchOrder(
      id,
      {
        trackingNumber: body.trackingNumber,
        carrierName: body.carrierName,
        expectedDeliveryDate: body.expectedDeliveryDate ? new Date(body.expectedDeliveryDate) : undefined,
        notes: body.notes,
      },
      req.user.id,
    );
  }

  @Put(':id/status')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.ORDER_MANAGER, UserRoleType.OPERATIONS_ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update order status with timeline tracking' })
  async updateStatus(
    @Param('id') id: string,
    @Body() body: { status: OrderStatus; reason?: string; trackingNumber?: string },
    @Req() req: any,
  ) {
    return this.ordersService.updateOrderStatus(
      id,
      body.status,
      req.user.id,
      body.reason,
      body.trackingNumber,
    );
  }

  @Post(':id/resend-dispatch-notification')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.ORDER_MANAGER, UserRoleType.OPERATIONS_ADMIN, UserRoleType.SALESMAN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Resend automated WhatsApp & SMS dispatch notification with tracking and invoice links' })
  async resendDispatchNotification(
    @Param('id') id: string,
    @Body() body: { channel?: 'WHATSAPP' | 'SMS' | 'ALL' },
  ) {
    return this.ordersService.resendDispatchNotification(id, body?.channel);
  }

  @Get(':id/dispatch-logs')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get dispatch notification history and delivery statuses for order' })
  async getDispatchLogs(@Param('id') id: string) {
    return this.ordersService.getDispatchLogs(id);
  }
}
