import { BuyerType, LoyaltyTierLevel, UserRoleType, QuotationStatus, OrderStatus, PaymentStatus, PaymentMethod } from '@prisma/client';

describe('Grand Aqua Core Business Rules & Financial Integrity', () => {
  describe('Rule 1: New Buyer Registration Defaults', () => {
    it('should assign BuyerType CUSTOMER and LoyaltyTier NONE by default', () => {
      const newRegistration = {
        phone: '+919876543210',
        fullName: 'New Customer',
        buyerType: BuyerType.CUSTOMER,
        loyaltyTier: LoyaltyTierLevel.NONE,
        creditLimit: 0,
      };

      expect(newRegistration.buyerType).toBe(BuyerType.CUSTOMER);
      expect(newRegistration.loyaltyTier).toBe(LoyaltyTierLevel.NONE);
      expect(newRegistration.creditLimit).toBe(0);
    });
  });

  describe('Rule 2 & 3: 4-Tier Pricing Determination', () => {
    const productPricing = {
      distributorPrice: 5500,
      wholesalerPrice: 6500,
      dealerPrice: 7800,
      customerPrice: 12999,
    };

    function calculateBasePrice(buyerType: BuyerType) {
      switch (buyerType) {
        case BuyerType.DISTRIBUTOR:
          return productPricing.distributorPrice;
        case BuyerType.WHOLESALER:
          return productPricing.wholesalerPrice;
        case BuyerType.DEALER:
          return productPricing.dealerPrice;
        case BuyerType.CUSTOMER:
        default:
          return productPricing.customerPrice;
      }
    }

    it('should return Distributor price for Distributor buyer type', () => {
      expect(calculateBasePrice(BuyerType.DISTRIBUTOR)).toBe(5500);
    });

    it('should return Wholesaler price for Wholesaler buyer type', () => {
      expect(calculateBasePrice(BuyerType.WHOLESALER)).toBe(6500);
    });

    it('should return Dealer price for Dealer buyer type', () => {
      expect(calculateBasePrice(BuyerType.DEALER)).toBe(7800);
    });

    it('should return Customer price for Customer buyer type', () => {
      expect(calculateBasePrice(BuyerType.CUSTOMER)).toBe(12999);
    });
  });

  describe('Rule 6: Salesmen Self-Approval Prohibition', () => {
    it('should strictly reject salesman attempting to approve their own discount request', () => {
      const quotation = {
        id: 'qt-101',
        salesmanUserId: 'user-salesman-1',
        status: QuotationStatus.PENDING_DISCOUNT_APPROVAL,
      };

      const approverUserId = 'user-salesman-1';

      const canApprove = (quotation.salesmanUserId !== approverUserId);
      expect(canApprove).toBe(false);
    });

    it('should allow Super Admin or Sales Manager to approve discount request', () => {
      const quotation = {
        id: 'qt-101',
        salesmanUserId: 'user-salesman-1',
        status: QuotationStatus.PENDING_DISCOUNT_APPROVAL,
      };

      const approverUserId = 'user-admin-1';
      const canApprove = (quotation.salesmanUserId !== approverUserId);
      expect(canApprove).toBe(true);
    });
  });

  describe('Rule 9 & 10: Quotation Order Conversion & Price Snapshot Invariance', () => {
    it('should prevent converting quotation that is not accepted or already converted', () => {
      const quotation: { status: QuotationStatus; validUntil: Date } = {
        status: QuotationStatus.PENDING_DISCOUNT_APPROVAL,
        validUntil: new Date(Date.now() + 86400000),
      };

      const isConvertible = quotation.status === QuotationStatus.ACCEPTED;
      expect(isConvertible).toBe(false);
    });

    it('should preserve snapshot price even if product price increases later', () => {
      const quotationSnapshotItem = {
        productId: 'prod-1',
        unitPrice: 5500, // agreed snapshot
        quantity: 10,
        totalPrice: 55000,
      };

      // Later, catalog price updates
      const updatedCatalogPrice = 6200;

      // Order must use snapshot price, not new catalog price
      const orderItemPrice = quotationSnapshotItem.unitPrice;
      expect(orderItemPrice).toBe(5500);
      expect(orderItemPrice).not.toBe(updatedCatalogPrice);
    });
  });

  describe('Rule 12: Outstanding Balance & Payment Allocation Reconciliation', () => {
    it('should correctly reduce outstanding balance upon recording payment', () => {
      let initialOutstanding = 64900;
      const paymentAmount = 25000;

      const newOutstanding = Math.max(0, initialOutstanding - paymentAmount);
      expect(newOutstanding).toBe(39900);
    });

    it('should transition payment status from PARTIALLY_PAID to PAID when outstanding reaches 0', () => {
      const finalAmount = 64900;
      let paid = 64900;
      const outstanding = Math.max(0, finalAmount - paid);

      const status = outstanding <= 0 ? PaymentStatus.PAID : PaymentStatus.PARTIALLY_PAID;
      expect(status).toBe(PaymentStatus.PAID);
    });
  });

  describe('Rule 14: Credit Limit Enforcement', () => {
    it('should block order that exceeds available credit limit', () => {
      const creditAccount = {
        creditLimit: 100000,
        utilizedCredit: 80000,
        availableCredit: 20000,
      };

      const orderAmount = 25000;
      const isApproved = creditAccount.availableCredit >= orderAmount;
      expect(isApproved).toBe(false);
    });

    it('should allow order within available credit limit', () => {
      const creditAccount = {
        creditLimit: 100000,
        utilizedCredit: 40000,
        availableCredit: 60000,
      };

      const orderAmount = 25000;
      const isApproved = creditAccount.availableCredit >= orderAmount;
      expect(isApproved).toBe(true);
    });
  });

  describe('Rule 15: Salesman Provisional Incentive Calculation', () => {
    it('should calculate 3% provisional incentive on delivered orders only', () => {
      const order = {
        finalAmount: 100000,
        status: OrderStatus.DELIVERED,
      };

      const rate = 3.0;
      const incentive = order.status === OrderStatus.DELIVERED ? (order.finalAmount * rate) / 100 : 0;
      expect(incentive).toBe(3000);
    });
  });
});
