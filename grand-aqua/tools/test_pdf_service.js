const { PdfService } = require('d:/grand_aqua_full/grand-aqua/grand aqua backend/dist/src/pdf/pdf.service.js');
const fs = require('fs');

async function testPdf() {
  const pdfService = new PdfService();

  const mockQuotation0Gst = {
    quotationNumber: 'GA-QT-2026-0001',
    createdAt: new Date(),
    validUntil: new Date(Date.now() + 15 * 86400000),
    taxRate: 0,
    subtotal: 25500,
    taxAmount: 0,
    shippingCharges: 0,
    additionalDiscountApproved: 0,
    finalTotal: 25500,
    paymentTerms: 'Payment on Delivery',
    buyer: {
      businessName: 'Apex Water Systems',
      buyerType: 'DISTRIBUTOR',
      gstin: '32ABCDE1234F1Z5',
      user: { fullName: 'Rajesh Verma', phone: '9876543210', email: 'rajesh@apexwater.in' },
      addresses: [{ streetAddress: 'Industrial Estate', city: 'Ernakulam', state: 'Kerala', pinCode: '682001' }]
    },
    items: [
      {
        productName: 'Grand Aqua 100 GPD Membrane',
        sku: 'MEM-100GPD',
        quantity: 3,
        unitPrice: 8500,
        taxRate: 0,
        taxAmount: 0,
        totalPrice: 25500,
      }
    ]
  };

  const mockApprovedQuotation12Gst = {
    ...mockQuotation0Gst,
    quotationNumber: 'GA-QT-2026-0002',
    taxRate: 12,
    taxAmount: 3060,
    shippingCharges: 450,
    finalTotal: 29010,
  };

  const mockOrder5Gst = {
    orderNumber: 'GA-ORD-2026-0001',
    createdAt: new Date(),
    taxRate: 5,
    subtotal: 50000,
    taxTotal: 2500,
    shippingCharges: 500,
    discountTotal: 0,
    finalAmount: 53000,
    paymentTerms: 'Approved Credit (30 Days)',
    buyer: mockQuotation0Gst.buyer,
    shippingAddress: mockQuotation0Gst.buyer.addresses[0],
    billingAddress: mockQuotation0Gst.buyer.addresses[0],
    items: [
      {
        productName: 'Commercial RO Membrane Housing',
        sku: 'RO-HOU-4040',
        quantity: 10,
        unitPrice: 5000,
        taxAmount: 250,
        totalPrice: 5250,
      }
    ]
  };

  console.log('Testing Buyer Quotation (0% GST - Pending):');
  for (const tpl of ['1', '2', '3']) {
    const buf = await pdfService.generateQuotationPdf(mockQuotation0Gst, tpl);
    console.log(`- Quotation T${tpl} generated, bytes:`, buf.length);
  }

  console.log('\nTesting Approved Quotation (12% GST):');
  for (const tpl of ['1', '2', '3']) {
    const buf = await pdfService.generateQuotationPdf(mockApprovedQuotation12Gst, tpl);
    console.log(`- Quotation T${tpl} generated, bytes:`, buf.length);
  }

  console.log('\nTesting Invoice (5% GST):');
  for (const tpl of ['1', '2', '3']) {
    const buf = await pdfService.generateInvoicePdf(mockOrder5Gst, null, tpl);
    console.log(`- Invoice T${tpl} generated, bytes:`, buf.length);
  }

  console.log('\nAll 9 PDF permutations generated successfully!');
}

testPdf().catch(console.error);
