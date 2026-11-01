import { IsBoolean, IsNumber, IsOptional, IsString, Min } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type, Transform } from 'class-transformer';

export class UpdateLoyaltyConfigDto {
  @ApiPropertyOptional({ description: 'Global toggle to enable or disable loyalty points for all buyers' })
  @IsOptional()
  @Transform(({ value }) => (value === true || value === 'true' || value === 1 || value === '1' ? true : value === false || value === 'false' || value === 0 || value === '0' ? false : undefined))
  @IsBoolean()
  enabled?: boolean;

  @ApiPropertyOptional({ description: 'Alias for enabled' })
  @IsOptional()
  @Transform(({ value }) => (value === true || value === 'true' || value === 1 || value === '1' ? true : value === false || value === 'false' || value === 0 || value === '0' ? false : undefined))
  @IsBoolean()
  programEnabled?: boolean;

  @ApiPropertyOptional({ description: 'Percentage of total purchase value given as points (e.g. 0.5 for 0.5%)', default: 0.5 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  percentage?: number;

  @ApiPropertyOptional({ description: 'Rupee rate per point (e.g. 1.0)', default: 1.0 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0.01)
  rupeePerPoint?: number;

  @ApiPropertyOptional({ description: 'Alias for rupeePerPoint' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0.01)
  pointRupeeRate?: number;
}

export class AdjustPointsDto {
  @ApiPropertyOptional({ description: 'Amount of points to add or reduce', example: 100 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0.1)
  amount?: number;

  @ApiPropertyOptional({ description: 'Alias for amount', example: 100 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0.1)
  points?: number;

  @ApiProperty({ description: 'Type of adjustment: CREDIT or DEBIT', enum: ['CREDIT', 'DEBIT'] })
  @IsString()
  type: 'CREDIT' | 'DEBIT';

  @ApiProperty({ description: 'Reason or remarks for this manual adjustment', example: 'Seasonal festival gift points' })
  @IsString()
  reason: string;
}

export class ToggleBuyerLoyaltyDto {
  @ApiPropertyOptional({ description: 'Whether loyalty points are enabled for this specific buyer' })
  @IsOptional()
  @Transform(({ value }) => (value === true || value === 'true' || value === 1 || value === '1' ? true : value === false || value === 'false' || value === 0 || value === '0' ? false : undefined))
  @IsBoolean()
  enabled?: boolean;

  @ApiPropertyOptional({ description: 'Alias for enabled' })
  @IsOptional()
  @Transform(({ value }) => (value === true || value === 'true' || value === 1 || value === '1' ? true : value === false || value === 'false' || value === 0 || value === '0' ? false : undefined))
  @IsBoolean()
  loyaltyEnabled?: boolean;
}

export class CreateGiftDto {
  @ApiProperty({ description: 'Gift reward title', example: 'Grand Aqua Stainless Steel Water Bottle' })
  @IsString()
  title: string;

  @ApiPropertyOptional({ description: 'Detailed description of the gift reward' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ description: 'Image URL for the gift item' })
  @IsOptional()
  @IsString()
  imageUrl?: string;

  @ApiProperty({ description: 'Number of loyalty points required to redeem this gift', example: 500 })
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  pointsRequired: number;

  @ApiPropertyOptional({ description: 'Stock quantity available for redemption', default: 100 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  stockQuantity?: number;

  @ApiPropertyOptional({ description: 'Alias for stockQuantity' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  stock?: number;

  @ApiPropertyOptional({ description: 'Whether the gift is active and visible to buyers', default: true })
  @IsOptional()
  @Transform(({ value }) => (value === true || value === 'true' || value === 1 || value === '1' ? true : value === false || value === 'false' || value === 0 || value === '0' ? false : undefined))
  @IsBoolean()
  isActive?: boolean;
}

export class UpdateGiftDto {
  @ApiPropertyOptional({ description: 'Gift reward title' })
  @IsOptional()
  @IsString()
  title?: string;

  @ApiPropertyOptional({ description: 'Detailed description of the gift reward' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ description: 'Image URL for the gift item' })
  @IsOptional()
  @IsString()
  imageUrl?: string;

  @ApiPropertyOptional({ description: 'Number of loyalty points required to redeem this gift' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  pointsRequired?: number;

  @ApiPropertyOptional({ description: 'Stock quantity available for redemption' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  stockQuantity?: number;

  @ApiPropertyOptional({ description: 'Alias for stockQuantity' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  stock?: number;

  @ApiPropertyOptional({ description: 'Whether the gift is active and visible to buyers' })
  @IsOptional()
  @Transform(({ value }) => (value === true || value === 'true' || value === 1 || value === '1' ? true : value === false || value === 'false' || value === 0 || value === '0' ? false : undefined))
  @IsBoolean()
  isActive?: boolean;
}

export class RedeemGiftDto {
  @ApiProperty({ description: 'ID of the gift to redeem' })
  @IsString()
  giftId: string;

  @ApiPropertyOptional({ description: 'Delivery address or special instructions' })
  @IsOptional()
  @IsString()
  deliveryNotes?: string;

  @ApiPropertyOptional({ description: 'Alias for deliveryNotes' })
  @IsOptional()
  @IsString()
  notes?: string;
}

export class UpdateRedemptionStatusDto {
  @ApiProperty({ description: 'Status: REQUESTED, APPROVED, DISPATCHED, DELIVERED, REJECTED', enum: ['REQUESTED', 'APPROVED', 'DISPATCHED', 'DELIVERED', 'REJECTED'] })
  @IsString()
  status: 'REQUESTED' | 'APPROVED' | 'DISPATCHED' | 'DELIVERED' | 'REJECTED';

  @ApiPropertyOptional({ description: 'Super Admin remarks or dispatch tracking details' })
  @IsOptional()
  @IsString()
  adminRemarks?: string;
}
