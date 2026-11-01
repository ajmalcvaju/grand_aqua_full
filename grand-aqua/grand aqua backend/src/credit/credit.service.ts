import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreditStatus } from '@prisma/client';

@Injectable()
export class CreditService {
  constructor(private prisma: PrismaService) {}

  async findAllAccounts() {
    const buyers = await this.prisma.buyerProfile.findMany({
      include: {
        user: true,
        assignedSalesman: { include: { user: true } },
        creditAccount: true,
      },
      orderBy: { createdAt: 'desc' },
    });

    for (const buyer of buyers) {
      if (!buyer.creditAccount) {
        await this.prisma.creditAccount.create({
          data: {
            buyerProfileId: buyer.id,
            creditLimit: Number(buyer.creditLimit) || 0,
            utilizedCredit: Number(buyer.outstandingBalance) || 0,
            availableCredit: Math.max(0, (Number(buyer.creditLimit) || 0) - (Number(buyer.outstandingBalance) || 0)),
            paymentTermsDays: buyer.creditDays || 15,
            status: CreditStatus.ACTIVE,
          },
        });
      }
    }

    return this.prisma.creditAccount.findMany({
      include: {
        buyer: {
          include: {
            user: true,
            assignedSalesman: { include: { user: true } },
          },
        },
      },
      orderBy: { creditLimit: 'desc' },
    });
  }

  async getBuyerCredit(buyerProfileId: string) {
    const account = await this.prisma.creditAccount.findUnique({
      where: { buyerProfileId },
      include: {
        buyer: { include: { user: true } },
        transactions: {
          orderBy: { createdAt: 'desc' },
          take: 30,
        },
      },
    });

    if (!account) {
      throw new NotFoundException('Credit facility not found for this buyer');
    }

    return account;
  }

  async setOrUpdateLimit(
    buyerProfileId: string,
    data: {
      creditLimit: number;
      paymentTermsDays?: number;
      reason: string;
      adminId: string;
    },
  ) {
    let account = await this.prisma.creditAccount.findUnique({
      where: { buyerProfileId },
    });

    const newLimit = Number(data.creditLimit);
    if (newLimit < 0) throw new BadRequestException('Credit limit cannot be negative');
    const terms = data.paymentTermsDays !== undefined ? Number(data.paymentTermsDays) : (account?.paymentTermsDays || 15);

    return this.prisma.$transaction(async (tx) => {
      if (!account) {
        account = await tx.creditAccount.create({
          data: {
            buyerProfileId,
            creditLimit: newLimit,
            utilizedCredit: 0,
            availableCredit: newLimit,
            paymentTermsDays: terms,
            status: CreditStatus.ACTIVE,
            approvedBy: data.adminId,
            approvedAt: new Date(),
          },
        });
      } else {
        const diff = newLimit - Number(account.creditLimit);
        const utilized = Number(account.utilizedCredit) || 0;
        const newAvailable = Math.max(0, newLimit - utilized);

        account = await tx.creditAccount.update({
          where: { id: account.id },
          data: {
            creditLimit: newLimit,
            availableCredit: newAvailable,
            paymentTermsDays: terms,
            approvedBy: data.adminId,
            approvedAt: new Date(),
          },
        });

        await tx.creditTransaction.create({
          data: {
            creditAccountId: account.id,
            transactionType: diff >= 0 ? 'LIMIT_INCREASE' : 'LIMIT_DECREASE',
            amount: Math.abs(diff),
            balanceAfter: newAvailable,
            referenceType: 'MANUAL',
            notes: data.reason,
            createdBy: data.adminId,
          },
        });
      }

      await tx.buyerProfile.update({
        where: { id: buyerProfileId },
        data: {
          creditLimit: newLimit,
          creditDays: terms,
        },
      });

      return account;
    });
  }

  async applyForCredit(buyerProfileId: string, requestedLimit: number, reason: string) {
    return this.prisma.creditApplication.create({
      data: {
        buyerProfileId,
        requestedLimit,
        reason,
        status: 'PENDING',
      },
    });
  }
}
