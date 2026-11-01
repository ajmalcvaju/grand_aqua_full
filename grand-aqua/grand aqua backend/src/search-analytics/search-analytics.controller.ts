import { Controller, Get, Post, Param, Body, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { SearchAnalyticsService } from './search-analytics.service';
import { AuthGuard } from '@nestjs/passport';

@ApiTags('Search Analytics & Buyer Keywords')
@Controller('search-analytics')
export class SearchAnalyticsController {
  constructor(private searchAnalyticsService: SearchAnalyticsService) {}

  @Post('log')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Log a keyword searched by logged-in buyer' })
  async logSearch(@Body('keyword') keyword: string, @Req() req: any) {
    const buyerProfileId = req.user?.buyerProfile?.id;
    return this.searchAnalyticsService.logKeyword(req.user?.id, keyword, buyerProfileId);
  }

  @Get('buyers')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List all buyers who searched keywords with counts' })
  @ApiQuery({ name: 'search', required: false })
  async getBuyersWithSearches(@Query('search') search?: string) {
    return this.searchAnalyticsService.getBuyersWithSearches(search);
  }

  @Get('buyer/:buyerProfileId')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get keywords searched by a specific buyer with search frequencies' })
  async getBuyerSearchKeywords(@Param('buyerProfileId') buyerProfileId: string) {
    return this.searchAnalyticsService.getBuyerSearchKeywords(buyerProfileId);
  }
}
