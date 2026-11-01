import { Controller, Post, Body, Get, UseGuards, Req, Ip, Headers } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { AdminLoginDto, RequestOtpDto, VerifyOtpDto, BuyerPasswordLoginDto, BuyerRegisterDto, BuyerForgotPasswordResetDto } from './dto/login.dto';
import { AuthGuard } from '@nestjs/passport';

@ApiTags('Authentication')
@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('admin/login')
  @ApiOperation({ summary: 'Login for Super Admin, Admin staff, and Salesmen' })
  @ApiResponse({ status: 200, description: 'Authentication successful with JWT' })
  async adminLogin(
    @Body() dto: AdminLoginDto,
    @Ip() ip: string,
    @Headers('user-agent') userAgent: string,
  ) {
    return this.authService.adminLogin(dto, ip, userAgent);
  }

  @Post('buyer/request-otp')
  @ApiOperation({ summary: 'Request OTP for Buyer mobile login' })
  async requestBuyerOtp(@Body() dto: RequestOtpDto) {
    return this.authService.requestBuyerOtp(dto.phone);
  }

  @Post('buyer/login')
  @ApiOperation({ summary: 'Direct login with phone number (bypasses OTP)' })
  async directBuyerLogin(
    @Body() dto: VerifyOtpDto,
    @Ip() ip: string,
    @Headers('user-agent') userAgent: string,
  ) {
    return this.authService.verifyBuyerOtp({ ...dto, otp: '123456' }, ip, userAgent);
  }

  @Post('buyer/verify-otp')
  @ApiOperation({ summary: 'Verify OTP and authenticate or register Buyer' })
  async verifyBuyerOtp(
    @Body() dto: VerifyOtpDto,
    @Ip() ip: string,
    @Headers('user-agent') userAgent: string,
  ) {
    return this.authService.verifyBuyerOtp(dto, ip, userAgent);
  }

  @Post('buyer/password-login')
  @ApiOperation({ summary: 'Login for Buyer using Mobile Number or Username and Password' })
  async buyerPasswordLogin(
    @Body() dto: BuyerPasswordLoginDto,
    @Ip() ip: string,
    @Headers('user-agent') userAgent: string,
  ) {
    return this.authService.buyerPasswordLogin(dto, ip, userAgent);
  }

  @Post('buyer/register')
  @ApiOperation({ summary: 'Register a new Buyer with Company Name and Mobile Number only' })
  async buyerRegister(@Body() dto: BuyerRegisterDto) {
    return this.authService.buyerRegister(dto);
  }

  @Post('buyer/forgot-password/request-otp')
  @ApiOperation({ summary: 'Request OTP for Buyer password reset' })
  async forgotPasswordRequestOtp(@Body() dto: RequestOtpDto) {
    return this.authService.requestBuyerOtp(dto.phone);
  }

  @Post('buyer/forgot-password/reset')
  @ApiOperation({ summary: 'Verify OTP and reset Buyer password' })
  async forgotPasswordReset(@Body() dto: BuyerForgotPasswordResetDto) {
    return this.authService.buyerForgotPasswordReset(dto);
  }

  @Get('me')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get currently authenticated user profile' })
  async getProfile(@Req() req: any) {
    return this.authService.getProfile(req.user.id);
  }
}
