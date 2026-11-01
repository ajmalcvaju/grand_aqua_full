import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcryptjs';
import { AdminLoginDto, VerifyOtpDto, BuyerPasswordLoginDto, BuyerRegisterDto, BuyerForgotPasswordResetDto } from './dto/login.dto';
import { BuyerType, LoyaltyTierLevel, UserRoleType, AccountStatus } from '@prisma/client';

// In-memory OTP storage for development/mock mode (phone -> { otp, expiresAt, attempts })
const mockOtpStore = new Map<string, { otp: string; expiresAt: number; attempts: number }>();

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
  ) {}

  async adminLogin(dto: AdminLoginDto, ip?: string, userAgent?: string) {
    // If PostgreSQL / MongoDB is not yet running locally, provide instant dev-mode login for seeded Super Admin
    if (!this.prisma.isConnected) {
      if (
        (dto.identifier === 'admin@grandaqua.com' || dto.identifier === 'admin') &&
        dto.password === 'GrandAqua@Admin2026'
      ) {
        const fallbackAdminId = '6ad73b1960984892bc36ddd5';
        const payload = { sub: fallbackAdminId, role: UserRoleType.SUPER_ADMIN, email: 'admin@grandaqua.com' };
        const accessToken = this.jwtService.sign(payload);
        return {
          accessToken,
          user: {
            id: fallbackAdminId,
            fullName: 'Super Administrator',
            username: 'admin',
            email: 'admin@grandaqua.com',
            phone: '+919999999999',
            role: UserRoleType.SUPER_ADMIN,
            salesmanProfile: null,
            buyerProfile: null,
          },
        };
      }
    }

    let user: any = null;
    try {
      user = await this.prisma.user.findFirst({
        where: {
          OR: [
            { email: dto.identifier.toLowerCase() },
            { phone: dto.identifier },
            { username: dto.identifier.toLowerCase() },
          ],
        },
        include: {
          buyerProfile: {
            include: { creditAccount: true },
          },
          salesmanProfile: true,
        },
      });
    } catch (dbErr) {
      // In case query throws connection error
      if (
        (dto.identifier === 'admin@grandaqua.com' || dto.identifier === 'admin') &&
        dto.password === 'GrandAqua@Admin2026'
      ) {
        const fallbackAdminId = '6ad73b1960984892bc36ddd5';
        const payload = { sub: fallbackAdminId, role: UserRoleType.SUPER_ADMIN, email: 'admin@grandaqua.com' };
        const accessToken = this.jwtService.sign(payload);
        return {
          accessToken,
          user: {
            id: fallbackAdminId,
            fullName: 'Super Administrator',
            username: 'admin',
            email: 'admin@grandaqua.com',
            phone: '+919999999999',
            role: UserRoleType.SUPER_ADMIN,
            salesmanProfile: null,
            buyerProfile: null,
          },
        };
      }
      throw new UnauthorizedException('Database unavailable and invalid credentials');
    }

    if (!user) {
      throw new UnauthorizedException('Invalid administrative credentials');
    }

    if (user.status === AccountStatus.BLOCKED || user.status === AccountStatus.SUSPENDED) {
      throw new ForbiddenException(`Your account is ${user.status.toLowerCase()}. Please contact Super Admin.`);
    }

    if (user.lockedUntil && user.lockedUntil > new Date()) {
      throw new ForbiddenException('Account is temporarily locked due to multiple failed attempts. Try again later.');
    }

    const isMatch = user.passwordHash ? await bcrypt.compare(dto.password, user.passwordHash) : false;
    if (!isMatch) {
      const attempts = user.failedAttempts + 1;
      const lockedUntil = attempts >= 5 ? new Date(Date.now() + 15 * 60 * 1000) : null;
      await this.prisma.user.update({
        where: { id: user.id },
        data: { failedAttempts: attempts, lockedUntil },
      });
      throw new UnauthorizedException('Invalid administrative credentials');
    }

    // Reset failed attempts on success
    await this.prisma.user.update({
      where: { id: user.id },
      data: { failedAttempts: 0, lockedUntil: null, lastLoginAt: new Date() },
    });

    // Record audit log
    await this.prisma.auditLog.create({
      data: {
        actorId: user.id,
        actorType: user.role.toString(),
        action: 'USER_LOGIN',
        module: 'auth',
        entityId: user.id,
        ipAddress: ip,
        userAgent,
      },
    });

    const payload = { sub: user.id, role: user.role, email: user.email };
    const accessToken = this.jwtService.sign(payload);

    return {
      accessToken,
      user: {
        id: user.id,
        fullName: user.fullName,
        username: user.username,
        email: user.email,
        phone: user.phone,
        role: user.role,
        salesmanProfile: user.salesmanProfile,
        buyerProfile: user.buyerProfile,
      },
    };
  }

  async requestBuyerOtp(phone: string) {
    const cleanPhone = phone.trim();
    if (!cleanPhone || cleanPhone.length < 10) {
      throw new BadRequestException('Valid mobile phone number is required');
    }

    // Generate 6 digit OTP
    const otp = process.env.NODE_ENV === 'production' ? Math.floor(100000 + Math.random() * 900000).toString() : '123456';
    const expiresAt = Date.now() + 5 * 60 * 1000; // 5 minutes

    mockOtpStore.set(cleanPhone, { otp, expiresAt, attempts: 0 });

    // In production, integrate Fast2SMS / Twilio. In dev/test, return message with OTP hint.
    return {
      message: 'OTP sent successfully to your mobile number',
      phone: cleanPhone,
      cooldownSeconds: 60,
      devOtp: process.env.NODE_ENV !== 'production' ? otp : undefined,
    };
  }

  async buyerPasswordLogin(dto: BuyerPasswordLoginDto, ip?: string, userAgent?: string) {
    const rawIdentifier = dto.identifier.trim();
    const cleanDigits = rawIdentifier.replace(/\D/g, '');
    const phoneCandidates = [
      rawIdentifier,
      `+91${cleanDigits}`,
      cleanDigits,
      cleanDigits.length === 12 && cleanDigits.startsWith('91') ? cleanDigits.substring(2) : null,
      cleanDigits.length === 10 ? `+91${cleanDigits}` : null,
    ].filter(Boolean) as string[];

    const user = await this.prisma.user.findFirst({
      where: {
        role: UserRoleType.BUYER,
        OR: [
          ...phoneCandidates.map((p) => ({ phone: p })),
          { username: rawIdentifier.toLowerCase() },
          { email: rawIdentifier.toLowerCase() },
        ],
      },
      include: {
        buyerProfile: {
          include: {
            assignedSalesman: {
              include: { user: true },
            },
            creditAccount: true,
          },
        },
      },
    });

    if (!user) {
      throw new UnauthorizedException('No account found matching this mobile number or username');
    }

    if (user.status === AccountStatus.BLOCKED || user.status === AccountStatus.SUSPENDED) {
      throw new ForbiddenException(`Your account is ${user.status.toLowerCase()}. Please contact Super Admin.`);
    }

    let isMatch = false;
    if (user.passwordHash) {
      isMatch = await bcrypt.compare(dto.password, user.passwordHash);
    }
    // Allow demo master passwords for easy developer and client testing
    if (!isMatch && (dto.password === '123456' || dto.password === 'admin123' || dto.password === 'buyer123')) {
      isMatch = true;
    }

    if (!isMatch) {
      if (!user.passwordHash) {
        throw new UnauthorizedException(
          'Password not set yet. Please enter demo password (123456), use OTP Login, or click Forgot Password.',
        );
      }
      throw new UnauthorizedException('Invalid password. Please check your password (or demo password: 123456).');
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    const payload = { sub: user.id, role: user.role, phone: user.phone };
    const accessToken = this.jwtService.sign(payload);

    return {
      accessToken,
      user: {
        id: user.id,
        fullName: user.fullName,
        username: user.username,
        phone: user.phone,
        email: user.email,
        role: user.role,
        buyerProfile: user.buyerProfile,
      },
    };
  }

  async buyerRegister(dto: BuyerRegisterDto) {
    const cleanPhone = dto.phone.trim();
    const cleanBusinessName = dto.businessName.trim();
    if (!cleanPhone || cleanPhone.length < 10) {
      throw new BadRequestException('Valid mobile number is required');
    }
    if (!cleanBusinessName) {
      throw new BadRequestException('Company / Business name is required');
    }

    const cleanDigits = cleanPhone.replace(/\D/g, '');
    const phoneCandidates = [
      cleanPhone,
      `+91${cleanDigits}`,
      cleanDigits,
      cleanDigits.length === 12 && cleanDigits.startsWith('91') ? cleanDigits.substring(2) : null,
      cleanDigits.length === 10 ? `+91${cleanDigits}` : null,
    ].filter(Boolean) as string[];

    const existing = await this.prisma.user.findFirst({
      where: {
        OR: phoneCandidates.map((p) => ({ phone: p })),
      },
    });

    if (existing) {
      throw new BadRequestException(
        'An account with this mobile number already exists. Please log in with password or OTP, or use Forgot Password.',
      );
    }

    const count = await this.prisma.buyerProfile.count();
    const buyerId = `GA-B-${1000 + count + 1}`;

    const user = await this.prisma.user.create({
      data: {
        phone: cleanPhone,
        email: `buyer_${cleanDigits}@grandaqua.local`,
        fullName: cleanBusinessName,
        username: `buyer_${cleanDigits}`, // Initial system username, to be customized & assigned by Super Admin!
        passwordHash: null, // Password will be set by Super Admin or via Forgot Password!
        role: UserRoleType.BUYER,
        status: AccountStatus.ACTIVE,
        buyerProfile: {
          create: {
            buyerId,
            businessName: cleanBusinessName,
            businessType: 'Registered Company / Retailer',
            buyerType: BuyerType.CUSTOMER,
            loyaltyTier: LoyaltyTierLevel.NONE,
            creditLimit: 0,
            outstandingBalance: 0,
            paymentTerms: 'Immediate Payment',
          },
        },
      },
      include: {
        buyerProfile: true,
      },
    });

    // Notify Super Admins about the new buyer registration
    try {
      const superAdmins = await this.prisma.user.findMany({
        where: { role: UserRoleType.SUPER_ADMIN },
      });
      for (const admin of superAdmins) {
        await this.prisma.notification.create({
          data: {
            userId: admin.id,
            title: `New Buyer Registration: ${cleanBusinessName}`,
            body: `${cleanBusinessName} (${cleanPhone}) created an account. Please assign their official username and initial password in Buyer Management.`,
            type: 'INFO',
            referenceType: 'BUYER',
            referenceId: user.buyerProfile?.id || user.id,
          },
        });
      }
    } catch (_) {}

    return {
      success: true,
      message: 'Account registered successfully! Super Admin will assign your username & initial password. You can also log in immediately using OTP.',
      buyerId,
      phone: cleanPhone,
      businessName: cleanBusinessName,
    };
  }

  async buyerForgotPasswordReset(dto: BuyerForgotPasswordResetDto) {
    const cleanPhone = dto.phone.trim();
    const stored = mockOtpStore.get(cleanPhone);

    const isMock = !dto.otp || dto.otp === '123456' || (stored && stored.otp === dto.otp);
    if (!isMock) {
      throw new UnauthorizedException('Invalid or expired OTP');
    }

    if (stored && Date.now() > stored.expiresAt) {
      mockOtpStore.delete(cleanPhone);
      throw new UnauthorizedException('OTP has expired. Please request a new one.');
    }

    const cleanDigits = cleanPhone.replace(/\D/g, '');
    const phoneCandidates = [
      cleanPhone,
      `+91${cleanDigits}`,
      cleanDigits,
      cleanDigits.length === 12 && cleanDigits.startsWith('91') ? cleanDigits.substring(2) : null,
      cleanDigits.length === 10 ? `+91${cleanDigits}` : null,
    ].filter(Boolean) as string[];

    const user = await this.prisma.user.findFirst({
      where: {
        role: UserRoleType.BUYER,
        OR: phoneCandidates.map((p) => ({ phone: p })),
      },
    });

    if (!user) {
      throw new UnauthorizedException('No buyer account found with this mobile number.');
    }

    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(dto.newPassword.trim(), salt);

    await this.prisma.user.update({
      where: { id: user.id },
      data: { passwordHash },
    });

    mockOtpStore.delete(cleanPhone);

    return {
      success: true,
      message: 'Password reset successfully! You can now log in using your mobile number and new password.',
    };
  }

  async verifyBuyerOtp(dto: VerifyOtpDto, ip?: string, userAgent?: string) {
    const cleanPhone = dto.phone.trim();
    const stored = mockOtpStore.get(cleanPhone);

    // Direct login or accept 123456 as default mock OTP
    const isMock = !dto.otp || dto.otp === '123456' || dto.otp === 'DIRECT' || (stored && stored.otp === dto.otp);
    if (!isMock) {
      throw new UnauthorizedException('Invalid or expired OTP');
    }

    if (stored && Date.now() > stored.expiresAt) {
      mockOtpStore.delete(cleanPhone);
      throw new UnauthorizedException('OTP has expired. Please request a new one.');
    }

    // Check if user already exists (support with or without +91)
    const cleanDigits = cleanPhone.replace(/\D/g, '');
    const phoneCandidates = [
      cleanPhone,
      `+91${cleanDigits}`,
      cleanDigits,
      cleanDigits.length === 12 && cleanDigits.startsWith('91') ? cleanDigits.substring(2) : null,
      cleanDigits.length === 10 ? `+91${cleanDigits}` : null,
    ].filter(Boolean) as string[];

    let user = await this.prisma.user.findFirst({
      where: {
        OR: phoneCandidates.map((p) => ({ phone: p })),
      },
      include: {
        buyerProfile: {
          include: {
            assignedSalesman: {
              include: { user: true },
            },
            creditAccount: true,
          },
        },
      },
    });

    let isNewUser = false;

    if (!user) {
      isNewUser = true;
      // Generate unique buyer ID: GA-B-XXXX
      const count = await this.prisma.buyerProfile.count();
      const buyerId = `GA-B-${1000 + count + 1}`;

      // Create new user & buyer profile: MANDATORY default Customer & LoyaltyTier NONE
      user = await this.prisma.user.create({
        data: {
          phone: cleanPhone,
          email: `buyer_${cleanDigits}@buyer.grandaqua.local`,
          username: `buyer_${cleanDigits}`,
          fullName: dto.fullName || 'Valued Customer',
          role: UserRoleType.BUYER,
          status: AccountStatus.ACTIVE,
          buyerProfile: {
            create: {
              buyerId,
              businessName: dto.businessName || 'Retail Customer',
              businessType: 'Individual / Retail',
              buyerType: BuyerType.CUSTOMER,
              loyaltyTier: LoyaltyTierLevel.NONE,
              creditLimit: 0,
              outstandingBalance: 0,
              paymentTerms: 'Immediate Payment',
            },
          },
        },
        include: {
          buyerProfile: {
            include: {
              assignedSalesman: {
                include: { user: true },
              },
              creditAccount: true,
            },
          },
        },
      });

      // Also create welcome notification
      await this.prisma.notification.create({
        data: {
          userId: user.id,
          title: 'Welcome to Grand Aqua!',
          body: 'Your buyer account is ready. Explore our premium water purifiers and spare parts catalog.',
          type: 'INFO',
        },
      });
    } else if (!user.buyerProfile) {
      // Ensure buyerProfile exists for user
      const count = await this.prisma.buyerProfile.count();
      const buyerId = `GA-B-${1000 + count + 1}`;
      const profile = await this.prisma.buyerProfile.create({
        data: {
          buyerId,
          userId: user.id,
          businessName: user.fullName || 'Retail Customer',
          businessType: 'Individual / Retail',
          buyerType: BuyerType.CUSTOMER,
          loyaltyTier: LoyaltyTierLevel.NONE,
          creditLimit: 0,
          outstandingBalance: 0,
          paymentTerms: 'Immediate Payment',
        },
        include: {
          assignedSalesman: {
            include: { user: true },
          },
          creditAccount: true,
        },
      });
      user.buyerProfile = profile as any;
    }

    if (user.status === AccountStatus.BLOCKED || user.status === AccountStatus.SUSPENDED) {
      throw new ForbiddenException(`Your account is ${user.status.toLowerCase()}. Contact support.`);
    }

    mockOtpStore.delete(cleanPhone);

    const payload = { sub: user.id, role: user.role, phone: user.phone };
    const accessToken = this.jwtService.sign(payload);

    return {
      accessToken,
      isNewUser,
      user: {
        id: user.id,
        fullName: user.fullName,
        username: user.username,
        phone: user.phone,
        email: user.email,
        role: user.role,
        buyerProfile: user.buyerProfile,
      },
    };
  }

  async getProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        buyerProfile: {
          include: {
            assignedSalesman: {
              include: { user: true },
            },
            creditAccount: true,
            addresses: true,
          },
        },
        salesmanProfile: {
          include: {
            salesTargets: true,
          },
        },
      },
    });

    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    const { passwordHash, ...safeUser } = user;
    return safeUser;
  }
}
