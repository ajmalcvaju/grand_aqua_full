import { Controller, Get, Post, Put, Delete, Body, Param, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { BannersService } from './banners.service';
import { AuthGuard } from '@nestjs/passport';
import { BannerAudienceType } from '@prisma/client';

@ApiTags('Banners & Audience Targeting')
@Controller('banners')
export class BannersController {
  constructor(private bannersService: BannersService) {}

  @Get('buyer-feed')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get active banners targeted to the current logged-in buyer' })
  async getBuyerFeed(@Req() req: any) {
    return this.bannersService.getBuyerFeed(req.user.id);
  }

  @Get()
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get all banners for Super Admin management' })
  async getAllBanners() {
    return this.bannersService.getAllBanners();
  }

  @Get(':id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get single banner by ID' })
  async getBannerById(@Param('id') id: string) {
    return this.bannersService.getBannerById(id);
  }

  @Post()
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create new banner with audience targeting' })
  async createBanner(
    @Body()
    body: {
      title: string;
      subtitle?: string;
      imageUrl: string;
      actionUrl?: string;
      targetType?: string;
      targetId?: string;
      audienceType: BannerAudienceType;
      selectedBuyerIds?: string[];
      displayOrder?: number;
      isActive?: boolean;
      startDate?: string;
      endDate?: string;
    },
  ) {
    return this.bannersService.createBanner(body);
  }

  @Put(':id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update banner details and audience' })
  async updateBanner(
    @Param('id') id: string,
    @Body()
    body: {
      title?: string;
      subtitle?: string;
      imageUrl?: string;
      actionUrl?: string;
      targetType?: string;
      targetId?: string;
      audienceType?: BannerAudienceType;
      selectedBuyerIds?: string[];
      displayOrder?: number;
      isActive?: boolean;
      startDate?: string;
      endDate?: string;
    },
  ) {
    return this.bannersService.updateBanner(id, body);
  }

  @Delete(':id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete banner' })
  async deleteBanner(@Param('id') id: string) {
    return this.bannersService.deleteBanner(id);
  }
}
