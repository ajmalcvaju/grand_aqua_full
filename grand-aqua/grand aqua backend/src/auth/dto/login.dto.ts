import { IsEmail, IsNotEmpty, IsOptional, IsString, MinLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class AdminLoginDto {
  @ApiProperty({ example: 'admin@grandaqua.com' })
  @IsString()
  @IsNotEmpty()
  identifier: string; // can be email or employee code or username

  @ApiProperty({ example: 'GrandAqua@Admin2026' })
  @IsString()
  @MinLength(6)
  password: string;
}

export class RequestOtpDto {
  @ApiProperty({ example: '+919876543210' })
  @IsString()
  @IsNotEmpty()
  phone: string;
}

export class VerifyOtpDto {
  @ApiProperty({ example: '+919876543210' })
  @IsString()
  @IsNotEmpty()
  phone: string;

  @ApiProperty({ example: '123456', required: false })
  @IsOptional()
  @IsString()
  otp?: string;

  @ApiProperty({ example: 'Rajesh Kumar', required: false })
  @IsOptional()
  @IsString()
  fullName?: string;

  @ApiProperty({ example: 'Aqua Pure Solutions', required: false })
  @IsOptional()
  @IsString()
  businessName?: string;
}

export class DirectBuyerLoginDto {
  @ApiProperty({ example: '+919876543210' })
  @IsString()
  @IsNotEmpty()
  phone: string;

  @ApiProperty({ example: 'Valued Customer', required: false })
  @IsOptional()
  @IsString()
  fullName?: string;
}

export class BuyerPasswordLoginDto {
  @ApiProperty({ example: '+919876543210 or username' })
  @IsString()
  @IsNotEmpty()
  identifier: string;

  @ApiProperty({ example: 'SecretPass123' })
  @IsString()
  @MinLength(4)
  password: string;
}

export class BuyerRegisterDto {
  @ApiProperty({ example: 'Apex Water Systems' })
  @IsString()
  @IsNotEmpty()
  businessName: string;

  @ApiProperty({ example: '+919876543210' })
  @IsString()
  @IsNotEmpty()
  phone: string;
}

export class BuyerForgotPasswordResetDto {
  @ApiProperty({ example: '+919876543210' })
  @IsString()
  @IsNotEmpty()
  phone: string;

  @ApiProperty({ example: '123456' })
  @IsString()
  @IsNotEmpty()
  otp: string;

  @ApiProperty({ example: 'NewSecret123' })
  @IsString()
  @MinLength(4)
  newPassword: string;
}
