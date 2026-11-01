import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { ProductsService } from './products.service';
import { BuyerType, UserRoleType } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { AuthGuard } from '@nestjs/passport';

@ApiTags('Products & Catalogue')
@Controller('products')
export class ProductsController {
  constructor(private productsService: ProductsService) {}

  @Get()
  @ApiOperation({ summary: 'Get product list with multi-tier pricing filters' })
  @ApiQuery({ name: 'search', required: false })
  @ApiQuery({ name: 'categoryId', required: false })
  @ApiQuery({ name: 'buyerType', enum: BuyerType, required: false })
  @ApiQuery({ name: 'isFeatured', required: false })
  @ApiQuery({ name: 'page', required: false })
  @ApiQuery({ name: 'limit', required: false })
  async findAll(@Query() query: any) {
    return this.productsService.findAll(query);
  }

  @Get('categories')
  @ApiOperation({ summary: 'Get all product categories with product counts' })
  async getCategories() {
    return this.productsService.getCategories();
  }

  @Get('categories/:id')
  @ApiOperation({ summary: 'Get single product category' })
  async getCategoryById(@Param('id') id: string) {
    return this.productsService.getCategoryById(id);
  }

  @Post('categories')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.PRODUCT_MANAGER)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create new product category' })
  async createCategory(@Body() body: any) {
    return this.productsService.createCategory(body);
  }

  @Put('categories/:id')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.PRODUCT_MANAGER)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update product category details' })
  async updateCategory(@Param('id') id: string, @Body() body: any) {
    return this.productsService.updateCategory(id, body);
  }

  @Delete('categories/:id')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.PRODUCT_MANAGER)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete product category (if empty)' })
  async deleteCategory(@Param('id') id: string) {
    return this.productsService.deleteCategory(id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get single product detail with buyer-specific pricing' })
  @ApiQuery({ name: 'buyerType', enum: BuyerType, required: false })
  async findOne(@Param('id') id: string, @Query('buyerType') buyerType?: BuyerType) {
    return this.productsService.findOne(id, buyerType);
  }

  @Post()
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.PRODUCT_MANAGER)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create new product with 4 independent tier prices' })
  async create(@Body() body: any) {
    return this.productsService.create(body);
  }

  @Put(':id')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.PRODUCT_MANAGER)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update full product details (name, category, media, 4-tier pricing)' })
  async update(@Param('id') id: string, @Body() body: any) {
    return this.productsService.updateProduct(id, body);
  }

  @Delete(':id')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.PRODUCT_MANAGER)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete product and associated media/pricing' })
  async delete(@Param('id') id: string) {
    return this.productsService.deleteProduct(id);
  }

  @Put(':id/pricing')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRoleType.SUPER_ADMIN, UserRoleType.PRODUCT_MANAGER)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update 4-tier pricing with audit history' })
  async updatePricing(@Param('id') id: string, @Body() body: any) {
    return this.productsService.updatePricing(id, body);
  }
}
