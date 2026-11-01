import { Controller, Get, Post, Param, Body, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ReviewsService } from './reviews.service';
import { AuthGuard } from '@nestjs/passport';

@ApiTags('Product Reviews & Ratings')
@Controller('reviews')
export class ReviewsController {
  constructor(private reviewsService: ReviewsService) {}

  @Get('product/:productId')
  @ApiOperation({ summary: 'Get approved reviews for a product' })
  async getProductReviews(@Param('productId') productId: string) {
    return this.reviewsService.getProductReviews(productId);
  }

  @Get('my-purchases')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get list of product IDs purchased by the current buyer' })
  async getMyPurchasedProducts(@Req() req: any) {
    return this.reviewsService.getMyPurchasedProducts(req.user.id);
  }

  @Get('eligibility/:productId')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Check if buyer is eligible to review a product' })
  async checkEligibility(@Param('productId') productId: string, @Req() req: any) {
    return this.reviewsService.checkReviewEligibility(req.user.id, productId);
  }

  @Post()
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Submit buyer review (available only if product was purchased)' })
  async addReview(
    @Body() body: { productId: string; rating: number; title: string; comment: string; orderId?: string },
    @Req() req: any,
  ) {
    return this.reviewsService.addReview(req.user.id, body);
  }
}
