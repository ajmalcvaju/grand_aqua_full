import { Injectable } from '@nestjs/common';
import * as PDFDocument from 'pdfkit';
import * as path from 'path';
import * as fs from 'fs';

@Injectable()
export class PdfService {
  private async loadItemImage(item: any): Promise<Buffer | null> {
    try {
      const imgObj =
        item.product?.media?.find((m: any) => m.mediaType === 'IMAGE') ||
        item.product?.media?.[0];
      let imgUrl = imgObj?.url || item.product?.imageUrl || item.imageUrl;
      if (!imgUrl) return this.getLocalFallbackImage();

      // 1. Check local file in uploads
      if (imgUrl.includes('/uploads/') || imgUrl.startsWith('uploads/')) {
        const fileName = path.basename(imgUrl.split('?')[0]);
        const localPath = path.join(process.cwd(), 'uploads', fileName);
        if (fs.existsSync(localPath)) {
          return fs.readFileSync(localPath);
        }
      }

      // 2. Base64
      if (imgUrl.startsWith('data:image')) {
        const parts = imgUrl.split(',');
        if (parts[1]) return Buffer.from(parts[1], 'base64');
      }

      // 3. HTTP / HTTPS external image
      if (imgUrl.startsWith('http://') || imgUrl.startsWith('https://')) {
        if (imgUrl.includes('unsplash.com')) {
          imgUrl = imgUrl.replace('auto=format', 'fm=jpg');
          if (!imgUrl.includes('fm=jpg')) imgUrl += '&fm=jpg';
        }

        const buf = await new Promise<Buffer | null>((resolve) => {
          try {
            const https = require('https');
            const http = require('http');
            const client = imgUrl.startsWith('https') ? https : http;
            client.get(imgUrl, { rejectUnauthorized: false, timeout: 5000 }, (res: any) => {
              if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                client.get(res.headers.location, { rejectUnauthorized: false, timeout: 5000 }, (redirRes: any) => {
                  if (redirRes.statusCode !== 200) return resolve(null);
                  const chunks: any[] = [];
                  redirRes.on('data', (c: any) => chunks.push(c));
                  redirRes.on('end', () => resolve(Buffer.concat(chunks)));
                  redirRes.on('error', () => resolve(null));
                }).on('error', () => resolve(null));
                return;
              }
              if (res.statusCode !== 200) return resolve(null);
              const chunks: any[] = [];
              res.on('data', (c: any) => chunks.push(c));
              res.on('end', () => resolve(Buffer.concat(chunks)));
              res.on('error', () => resolve(null));
            }).on('error', () => resolve(null));
          } catch {
            resolve(null);
          }
        });

        if (buf && buf.length > 10) {
          const isJpg = buf.length > 3 && buf[0] === 0xFF && buf[1] === 0xD8 && buf[2] === 0xFF;
          const isPng = buf.length > 4 && buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4E && buf[3] === 0x47;
          if (isJpg || isPng) {
            return buf;
          }
        }
      }
    } catch {
      // Fallback
    }

    return this.getLocalFallbackImage();
  }

  private getLocalFallbackImage(): Buffer | null {
    const fallbackPath = path.join(process.cwd(), 'uploads', 'hero-purifier_1792851724683_55i46y.png');
    if (fs.existsSync(fallbackPath)) {
      try {
        return fs.readFileSync(fallbackPath);
      } catch {}
    }
    return null;
  }

  private getOfficialLogoPath(): string | null {
    const p1 = path.join(process.cwd(), 'uploads', 'grand_aqua_official_logo.png');
    if (fs.existsSync(p1)) return p1;
    const p2 = path.join(process.cwd(), 'uploads', 'logo.jpg');
    if (fs.existsSync(p2)) return p2;
    return null;
  }

  private drawCameraPlaceholder(doc: any, cx: number, cy: number) {
    doc.circle(cx, cy, 13).strokeColor('#cbd5e1').lineWidth(0.8).stroke();
    doc.roundedRect(cx - 6.5, cy - 4.5, 13, 9, 1.5).strokeColor('#94a3b8').lineWidth(0.8).stroke();
    doc.circle(cx, cy + 0.2, 2.5).strokeColor('#94a3b8').lineWidth(0.8).stroke();
    doc.rect(cx - 2.5, cy - 6, 5, 1.5).strokeColor('#94a3b8').lineWidth(0.8).stroke();
    doc.moveTo(cx - 9, cy - 9).lineTo(cx + 9, cy + 9).strokeColor('#cbd5e1').lineWidth(0.8).stroke();
  }

  private numberToWords(num: number): string {
    const a = ['', 'One ', 'Two ', 'Three ', 'Four ', 'Five ', 'Six ', 'Seven ', 'Eight ', 'Nine ', 'Ten ', 'Eleven ', 'Twelve ', 'Thirteen ', 'Fourteen ', 'Fifteen ', 'Sixteen ', 'Seventeen ', 'Eighteen ', 'Nineteen '];
    const b = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    const inWords = (n: number): string => {
      let str = '';
      if (n > 9999999) {
        str += inWords(Math.floor(n / 10000000)) + 'Crore ';
        n %= 10000000;
      }
      if (n > 99999) {
        str += inWords(Math.floor(n / 100000)) + 'Lakh ';
        n %= 100000;
      }
      if (n > 999) {
        str += inWords(Math.floor(n / 1000)) + 'Thousand ';
        n %= 1000;
      }
      if (n > 99) {
        str += inWords(Math.floor(n / 100)) + 'Hundred ';
        n %= 100;
      }
      if (n > 0) {
        if (str !== '') str += 'and ';
        if (n < 20) str += a[n];
        else {
          str += b[Math.floor(n / 10)];
          if (n % 10 > 0) str += ' ' + a[n % 10];
        }
      }
      return str;
    };

    const rounded = Math.round(num);
    if (rounded === 0) return 'Zero Rupees Only';
    return `${inWords(rounded).trim()} Rupees Only`;
  }

  // ==========================================
  // MAIN ROUTERS
  // ==========================================
  async generateQuotationPdf(quotation: any, template: string = '1'): Promise<Buffer> {
    const items = quotation.items || [];
    const imageBuffers = await Promise.all(items.map((it: any) => this.loadItemImage(it)));
    const tpl = (template || '1').toString().toLowerCase();

    if (tpl === '2' || tpl === 'minimal') {
      return this.generateQuotationTemplate2(quotation, imageBuffers);
    }
    if (tpl === '3' || tpl === 'gst' || tpl === 'formal') {
      return this.generateQuotationTemplate3(quotation, imageBuffers);
    }
    return this.generateQuotationTemplate1(quotation, imageBuffers);
  }

  async generateInvoicePdf(order: any, invoice?: any, template: string = '1'): Promise<Buffer> {
    const items = order.items || [];
    const imageBuffers = await Promise.all(items.map((it: any) => this.loadItemImage(it)));
    const tpl = (template || '1').toString().toLowerCase();

    if (tpl === '2' || tpl === 'minimal') {
      return this.generateInvoiceTemplate2(order, invoice, imageBuffers);
    }
    if (tpl === '3' || tpl === 'gst' || tpl === 'formal') {
      return this.generateInvoiceTemplate3(order, invoice, imageBuffers);
    }
    return this.generateInvoiceTemplate1(order, invoice, imageBuffers);
  }

  // ==========================================
  // TEMPLATE 1: MODERN CORPORATE (NAVY)
  // ==========================================
  private generateQuotationTemplate1(quotation: any, imageBuffers: (Buffer | null)[]): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      const doc = new (PDFDocument as any)({ margin: 40, size: 'A4' });
      const buffers: Buffer[] = [];
      doc.on('data', buffers.push.bind(buffers));
      doc.on('end', () => resolve(Buffer.concat(buffers)));
      doc.on('error', (err: any) => reject(err));

      const items = quotation.items || [];

      // Top Banner
      doc.rect(40, 40, 515, 62).fill('#0284c7');
      const logo = this.getOfficialLogoPath();
      if (logo) {
        try { doc.image(logo, 480, 47, { fit: [60, 48] }); } catch {}
      }
      doc.fillColor('#ffffff').fontSize(20).font('Helvetica-Bold').text('GRAND AQUA', 55, 50);
      doc.fontSize(9.5).font('Helvetica').text('Pure | Safe | Healthy — Commercial & Residential RO Systems', 55, 73);
      doc.fontSize(8.5).text('GSTIN: 07AAAAA0000A1Z5 | Support: +91 98765 43210 | www.grandaqua.com', 55, 85);

      // Title & Meta Info
      doc.fillColor('#0f172a').fontSize(14).font('Helvetica-Bold').text('COMMERCIAL QUOTATION', 40, 114);
      doc.fontSize(8.5).font('Helvetica');
      doc.text(`Quotation #: ${quotation.quotationNumber || 'GA-QT-2026'}`, 40, 132);
      doc.text(`Date: ${new Date(quotation.createdAt || Date.now()).toLocaleDateString('en-IN')}`, 40, 144);
      doc.text(`Valid Until: ${new Date(quotation.validUntil || Date.now()).toLocaleDateString('en-IN')}`, 40, 156);
      doc.text(`Status: ${quotation.status || 'ISSUED'}`, 40, 168);

      // Buyer Info
      doc.font('Helvetica-Bold').text('Prepared For:', 320, 132);
      doc.font('Helvetica').text(`${quotation.buyer?.businessName || quotation.buyer?.user?.fullName || 'Valued Client'}`, 320, 144);
      doc.text(`Category: ${quotation.buyer?.buyerType || 'Standard'} | Tier: ${quotation.buyer?.loyaltyTier || 'SILVER'}`, 320, 156);
      doc.text(`Phone: ${quotation.buyer?.user?.phone || quotation.buyer?.user?.mobileNumber || 'N/A'}`, 320, 168);
      doc.text(`GSTIN: ${quotation.buyer?.gstin || 'Unregistered / Retail'}`, 320, 180);

      // Table layout
      const colX = { num: 40, img: 65, prod: 115, qty: 315, price: 375, total: 455 };
      const colW = { num: 25, img: 50, prod: 200, qty: 60, price: 80, total: 100 };
      let y = 198;

      const drawHeader = (currY: number) => {
        doc.rect(40, currY, 515, 22).fill('#0f172a');
        doc.fillColor('#ffffff').fontSize(8).font('Helvetica-Bold');
        doc.text('#', colX.num, currY + 6, { width: colW.num, align: 'center' });
        doc.text('IMAGE', colX.img, currY + 6, { width: colW.img, align: 'center' });
        doc.text('PRODUCT & SPECIFICATION', colX.prod + 6, currY + 6, { width: colW.prod - 12 });
        doc.text('QUANTITY', colX.qty, currY + 6, { width: colW.qty, align: 'center' });
        doc.text('UNIT PRICE (INR)', colX.price, currY + 6, { width: colW.price - 6, align: 'right' });
        doc.text('AMOUNT (INR)', colX.total, currY + 6, { width: colW.total - 6, align: 'right' });
      };

      drawHeader(y);
      y += 22;

      let totalUnits = 0;
      let calculatedTaxableSubtotal = 0;
      const rowHeight = 44;

      items.forEach((item: any, idx: number) => {
        if (y + rowHeight > 690) {
          doc.addPage();
          y = 40;
          drawHeader(y);
          y += 22;
        }

        doc.rect(40, y, 515, rowHeight).strokeColor('#e2e8f0').lineWidth(0.6).stroke();
        const qty = Number(item.quantity) || 1;
        const price = Number(item.unitPrice) || 0;
        const lineTaxableTotal = qty * price;
        totalUnits += qty;
        calculatedTaxableSubtotal += lineTaxableTotal;

        const rawTitle = (item.productName || item.product?.name || 'Water Purifier').trim();
        const sku = (item.sku || item.product?.sku || '').trim();
        let cleanTitle = rawTitle;
        if (sku && cleanTitle.includes(`(${sku})`)) {
          cleanTitle = cleanTitle.replace(`(${sku})`, '').trim();
        }
        const modelStr = sku ? `Model: ${sku}` : (item.product?.category?.name || 'Standard RO');

        // Divider lines
        doc.moveTo(colX.img, y).lineTo(colX.img, y + rowHeight).strokeColor('#e2e8f0').stroke();
        doc.moveTo(colX.prod, y).lineTo(colX.prod, y + rowHeight).strokeColor('#e2e8f0').stroke();
        doc.moveTo(colX.qty, y).lineTo(colX.qty, y + rowHeight).strokeColor('#e2e8f0').stroke();
        doc.moveTo(colX.price, y).lineTo(colX.price, y + rowHeight).strokeColor('#e2e8f0').stroke();
        doc.moveTo(colX.total, y).lineTo(colX.total, y + rowHeight).strokeColor('#e2e8f0').stroke();

        // 1. #
        doc.fillColor('#475569').font('Helvetica').fontSize(8);
        doc.text(`${idx + 1}`, colX.num, y + (rowHeight / 2) - 4, { width: colW.num, align: 'center' });

        // 2. Image
        const img = imageBuffers[idx];
        const imgSize = 32;
        const imgX = colX.img + (colW.img - imgSize) / 2;
        const imgY = y + (rowHeight - imgSize) / 2;
        if (img) {
          try {
            doc.roundedRect(imgX - 2, imgY - 2, imgSize + 4, imgSize + 4, 3).fillAndStroke('#f8fafc', '#e2e8f0');
            doc.image(img, imgX, imgY, { fit: [imgSize, imgSize], align: 'center', valign: 'center' });
          } catch {
            this.drawCameraPlaceholder(doc, colX.img + colW.img / 2, y + rowHeight / 2);
          }
        } else {
          this.drawCameraPlaceholder(doc, colX.img + colW.img / 2, y + rowHeight / 2);
        }

        // 3. Product & Spec
        doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5);
        doc.text(cleanTitle, colX.prod + 6, y + 8, { width: colW.prod - 12, height: 13, ellipsis: true });
        doc.fillColor('#0284c7').font('Helvetica-Bold').fontSize(7.5);
        doc.text(modelStr, colX.prod + 6, y + 24, { width: colW.prod - 12, height: 11, ellipsis: true });

        // 4. Qty
        doc.fillColor('#0f172a').font('Helvetica').fontSize(8);
        doc.text(`${qty.toFixed(2)} PCS`, colX.qty, y + (rowHeight / 2) - 4, { width: colW.qty, align: 'center' });

        // 5. Unit Price
        doc.text(price.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), colX.price, y + (rowHeight / 2) - 4, { width: colW.price - 6, align: 'right' });

        // 6. Total (without GST)
        doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5);
        doc.text(lineTaxableTotal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), colX.total, y + (rowHeight / 2) - 4, { width: colW.total - 6, align: 'right' });

        y += rowHeight;
      });

      // Bottom Row Total of table
      doc.rect(40, y, 515, 22).fill('#f8fafc');
      doc.rect(40, y, 515, 22).strokeColor('#cbd5e1').lineWidth(0.8).stroke();
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(9);
      doc.text('Total', colX.num, y + 6, { width: colX.total - colX.num - 10, align: 'right' });
      doc.text(`Rs. ${calculatedTaxableSubtotal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, colX.total, y + 6, { width: colW.total - 6, align: 'right' });
      y += 30;

      // Totals & Terms
      const subtotalVal = Number(quotation.subtotal) || calculatedTaxableSubtotal;
      const taxVal = Number(quotation.taxAmount) || (subtotalVal * 0.18);
      const discountVal = Number(quotation.additionalDiscountApproved) || 0;
      const shippingVal = Number(quotation.shippingCharges) || 0;
      const finalTotalVal = Number(quotation.finalTotal) || (subtotalVal + taxVal + shippingVal - discountVal);

      // Terms on left
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8).text('Commercial Terms & Warranty:', 40, y);
      doc.fillColor('#475569').font('Helvetica').fontSize(7.5);
      doc.text('• Valid for 15 days from issue date.', 40, y + 12);
      doc.text('• 1-year comprehensive manufacturer warranty on genuine internal components.', 40, y + 24);
      doc.text('• Dispatch within 24-48 business hours post confirmation.', 40, y + 36);

      // Financials on right
      let rY = y;
      doc.fillColor('#475569').font('Helvetica').fontSize(8).text('Subtotal (Taxable Value):', 290, rY);
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5).text(`Rs. ${subtotalVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rY, { width: 130, align: 'right' });
      rY += 14;

      const qTaxRate = quotation.taxRate !== undefined && quotation.taxRate !== null ? Number(quotation.taxRate) : 0;
      if (qTaxRate === 0) {
        doc.fillColor('#0369a1').font('Helvetica-Bold').fontSize(8).text('GST Tax Status:', 290, rY);
        doc.fillColor('#0369a1').font('Helvetica-Bold').fontSize(7.5).text('Applicable on Approval (5%–18%)', 390, rY, { width: 165, align: 'right' });
      } else {
        doc.fillColor('#0369a1').font('Helvetica-Bold').fontSize(8).text(`Taxes / GST (${qTaxRate}%):`, 290, rY);
        doc.fillColor('#0369a1').font('Helvetica-Bold').fontSize(8.5).text(`Rs. ${taxVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rY, { width: 130, align: 'right' });
      }
      rY += 14;

      if (discountVal > 0) {
        doc.fillColor('#16a34a').font('Helvetica-Bold').fontSize(8).text('Approved Concession:', 290, rY);
        doc.fillColor('#16a34a').font('Helvetica-Bold').fontSize(8.5).text(`- Rs. ${discountVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rY, { width: 130, align: 'right' });
        rY += 14;
      }

      if (shippingVal > 0) {
        doc.fillColor('#475569').font('Helvetica').fontSize(8).text('Shipping Charges:', 290, rY);
        doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5).text(`Rs. ${shippingVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rY, { width: 130, align: 'right' });
        rY += 14;
      }

      // Final Payable Box
      doc.rect(290, rY + 2, 265, 24).fill('#0f172a');
      doc.fillColor('#ffffff').font('Helvetica-Bold').fontSize(8.5).text('Final Payable Total:', 300, rY + 8);
      doc.fontSize(10).text(`Rs. ${finalTotalVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 420, rY + 7, { width: 130, align: 'right' });

      // Signatory
      const sigY = rY + 38;
      doc.moveTo(420, sigY).lineTo(555, sigY).strokeColor('#94a3b8').lineWidth(0.8).stroke();
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8).text('Authorized Signatory', 420, sigY + 4, { width: 135, align: 'center' });
      doc.fillColor('#64748b').font('Helvetica').fontSize(7.5).text('Grand Aqua Commercial Sales', 420, sigY + 14, { width: 135, align: 'center' });

      // Bottom footer
      doc.fillColor('#94a3b8').font('Helvetica').fontSize(7.5);
      doc.text(`Quotation: ${quotation.quotationNumber || 'GA-QT-2026'} | Template 1 (Modern)`, 40, 775, { lineBreak: false });
      doc.text('Page 1 of 1', 40, 775, { width: 515, align: 'right', lineBreak: false });

      doc.end();
    });
  }

  private generateInvoiceTemplate1(order: any, invoice: any, imageBuffers: (Buffer | null)[]): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      const doc = new (PDFDocument as any)({ margin: 40, size: 'A4' });
      const buffers: Buffer[] = [];
      doc.on('data', buffers.push.bind(buffers));
      doc.on('end', () => resolve(Buffer.concat(buffers)));
      doc.on('error', (err: any) => reject(err));

      const items = order.items || [];
      const rawInvNum = invoice?.invoiceNumber || order.invoices?.[0]?.invoiceNumber || order.orderNumber || '1063';
      let cleanDigits = rawInvNum.toString().replace(/[^0-9]/g, '');
      if (cleanDigits.length > 4) cleanDigits = cleanDigits.slice(-4);
      const invoiceNumber = `INV-2026-${cleanDigits.padStart(4, '0')}`;
      const invoiceDate = invoice?.invoiceDate
        ? new Date(invoice.invoiceDate).toLocaleDateString('en-GB')
        : new Date(order.createdAt || Date.now()).toLocaleDateString('en-GB');

      const buyerName = order.buyer?.businessName || order.buyer?.user?.fullName || 'Valued Buyer';
      const buyerPhone = order.buyer?.user?.phone || order.buyer?.user?.mobileNumber || '9847032612';
      const buyerGstin = order.buyer?.gstin || '32BMTPC7034C1ZD';

      let buyerAddress = 'Thathamangalam, Palakkad, Kerala, India - 678531';
      let bookingStation = 'Palakkad';
      let transportName = 'Keraleeya Surface Logistics';

      if (order.shippingAddress && typeof order.shippingAddress === 'object') {
        const addr = order.shippingAddress;
        buyerAddress = [addr.addressLine || addr.address, addr.city || addr.district, addr.state || 'Kerala', addr.pinCode || addr.postalCode].filter(Boolean).join(', ');
        bookingStation = addr.city || addr.district || bookingStation;
      }
      if (order.transportDetails && typeof order.transportDetails === 'object') {
        transportName = order.transportDetails.transporterName || order.transportDetails.carrier || transportName;
      }

      // Top Header
      doc.rect(40, 40, 515, 62).fill('#0f172a');
      const logo = this.getOfficialLogoPath();
      if (logo) {
        try { doc.image(logo, 480, 47, { fit: [60, 48] }); } catch {}
      }
      doc.fillColor('#ffffff').fontSize(20).font('Helvetica-Bold').text('GRAND AQUA', 55, 50);
      doc.fontSize(9.5).font('Helvetica').text('Pure | Safe | Healthy — Commercial & Residential RO Systems', 55, 73);
      doc.fontSize(8.5).text('GSTIN: 07AAAAA0000A1Z5 | Support: +91 98765 43210 | www.grandaqua.com', 55, 85);

      // Meta Strip
      const infoBoxY = 108;
      doc.rect(40, infoBoxY, 515, 34).strokeColor('#e2e8f0').lineWidth(0.8).stroke();
      doc.fillColor('#0284c7').font('Helvetica-Bold').fontSize(11).text('TAX INVOICE', 48, infoBoxY + 5);
      doc.fillColor('#475569').font('Helvetica').fontSize(8).text(`Invoice #: ${invoiceNumber}`, 48, infoBoxY + 20);
      doc.text(`Date: ${invoiceDate}`, 175, infoBoxY + 20);
      doc.text(`Order Ref: #${order.orderNumber || 'GA-ORD'}`, 280, infoBoxY + 20);
      doc.text(`Payment: ${order.paymentTerms || 'Payment on Delivery'}`, 390, infoBoxY + 20, { width: 160, ellipsis: true });

      // Logistics 4 columns
      const transY = 148;
      doc.rect(40, transY, 515, 46).strokeColor('#e2e8f0').lineWidth(0.8).stroke();
      doc.moveTo(165, transY).lineTo(165, transY + 46).strokeColor('#e2e8f0').stroke();
      doc.moveTo(290, transY).lineTo(290, transY + 46).strokeColor('#e2e8f0').stroke();
      doc.moveTo(425, transY).lineTo(425, transY + 46).strokeColor('#e2e8f0').stroke();

      doc.fillColor('#64748b').font('Helvetica-Bold').fontSize(7).text('SUPPLIER (CONSIGNOR)', 46, transY + 5);
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8).text('Grand Aqua Solutions', 46, transY + 16);
      doc.fillColor('#475569').font('Helvetica').fontSize(7.5).text('GSTIN: 07AAAAA0000A1Z5\nKerala - 678531', 46, transY + 26);

      doc.fillColor('#64748b').font('Helvetica-Bold').fontSize(7).text('BILLED TO (BUYER)', 172, transY + 5);
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8).text(buyerName, 172, transY + 16, { width: 110, ellipsis: true });
      doc.fillColor('#475569').font('Helvetica').fontSize(7.5).text(`GSTIN: ${buyerGstin}\nMob: ${buyerPhone}`, 172, transY + 26);

      doc.fillColor('#64748b').font('Helvetica-Bold').fontSize(7).text('SHIPPED TO (CONSIGNEE)', 296, transY + 5);
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8).text(bookingStation, 296, transY + 16, { width: 120, ellipsis: true });
      doc.fillColor('#475569').font('Helvetica').fontSize(7).text(buyerAddress, 296, transY + 26, { width: 124, height: 16, ellipsis: true });

      doc.fillColor('#64748b').font('Helvetica-Bold').fontSize(7).text('TRANSPORT / DISPATCH', 431, transY + 5);
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8).text(transportName, 431, transY + 16, { width: 118, ellipsis: true });
      doc.fillColor('#475569').font('Helvetica').fontSize(7.5).text(`Hub: ${bookingStation}\nVerified Sealed`, 431, transY + 26);

      // Table
      let tableY = 202;
      const colX = { num: 40, img: 62, prod: 110, qty: 305, price: 370, amount: 455 };
      const colW = { num: 22, img: 48, prod: 195, qty: 65, price: 85, amount: 100 };

      const drawTableHeader = (currY: number) => {
        doc.rect(40, currY, 515, 20).fill('#0f172a');
        doc.fillColor('#ffffff').font('Helvetica-Bold').fontSize(7.5);
        doc.text('#', colX.num, currY + 6, { width: colW.num, align: 'center' });
        doc.text('IMAGE', colX.img, currY + 6, { width: colW.img, align: 'center' });
        doc.text('PRODUCT & SPECIFICATION', colX.prod + 6, currY + 6, { width: colW.prod - 12 });
        doc.text('QUANTITY', colX.qty, currY + 6, { width: colW.qty, align: 'center' });
        doc.text('UNIT PRICE (INR)', colX.price, currY + 6, { width: colW.price - 6, align: 'right' });
        doc.text('AMOUNT (INR)', colX.amount, currY + 6, { width: colW.amount - 6, align: 'right' });
      };

      drawTableHeader(tableY);
      tableY += 20;

      let totalUnits = 0;
      let calculatedTaxableSubtotal = 0;
      const rowH = 44;

      items.forEach((item: any, idx: number) => {
        if (tableY + rowH > 680) {
          doc.addPage();
          tableY = 40;
          drawTableHeader(tableY);
          tableY += 20;
        }

        doc.rect(40, tableY, 515, rowH).strokeColor('#e2e8f0').lineWidth(0.6).stroke();
        const qty = Number(item.quantity) || 1;
        const price = Number(item.unitPrice) || 0;
        const lineTaxableAmount = qty * price;
        totalUnits += qty;
        calculatedTaxableSubtotal += lineTaxableAmount;

        const rawTitle = (item.productName || item.product?.name || 'Water Purifier').trim();
        const sku = (item.sku || item.product?.sku || '').trim();
        let cleanTitle = rawTitle;
        if (sku && cleanTitle.includes(`(${sku})`)) {
          cleanTitle = cleanTitle.replace(`(${sku})`, '').trim();
        }
        const modelStr = sku ? `Model: ${sku}` : (item.product?.category?.name || 'Standard RO');

        doc.moveTo(colX.img, tableY).lineTo(colX.img, tableY + rowH).strokeColor('#e2e8f0').stroke();
        doc.moveTo(colX.prod, tableY).lineTo(colX.prod, tableY + rowH).strokeColor('#e2e8f0').stroke();
        doc.moveTo(colX.qty, tableY).lineTo(colX.qty, tableY + rowH).strokeColor('#e2e8f0').stroke();
        doc.moveTo(colX.price, tableY).lineTo(colX.price, tableY + rowH).strokeColor('#e2e8f0').stroke();
        doc.moveTo(colX.amount, tableY).lineTo(colX.amount, tableY + rowH).strokeColor('#e2e8f0').stroke();

        // 1. #
        doc.fillColor('#475569').font('Helvetica').fontSize(8);
        doc.text(`${idx + 1}`, colX.num, tableY + (rowH / 2) - 4, { width: colW.num, align: 'center' });

        // 2. Image
        const imgBuffer = imageBuffers[idx];
        const imgSize = 32;
        const imgX = colX.img + (colW.img - imgSize) / 2;
        const imgY = tableY + (rowH - imgSize) / 2;
        if (imgBuffer) {
          try {
            doc.roundedRect(imgX - 2, imgY - 2, imgSize + 4, imgSize + 4, 3).fillAndStroke('#f8fafc', '#e2e8f0');
            doc.image(imgBuffer, imgX, imgY, { fit: [imgSize, imgSize], align: 'center', valign: 'center' });
          } catch {
            this.drawCameraPlaceholder(doc, colX.img + colW.img / 2, tableY + rowH / 2);
          }
        } else {
          this.drawCameraPlaceholder(doc, colX.img + colW.img / 2, tableY + rowH / 2);
        }

        // 3. Product & Spec
        doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5);
        doc.text(cleanTitle, colX.prod + 6, tableY + 8, { width: colW.prod - 12, height: 13, ellipsis: true });
        doc.fillColor('#0284c7').font('Helvetica-Bold').fontSize(7.5);
        doc.text(modelStr, colX.prod + 6, tableY + 24, { width: colW.prod - 12, height: 11, ellipsis: true });

        // 4. Qty
        doc.fillColor('#0f172a').font('Helvetica').fontSize(8);
        doc.text(`${qty.toFixed(2)} PCS`, colX.qty, tableY + (rowH / 2) - 4, { width: colW.qty, align: 'center' });

        // 5. Unit Price
        doc.text(price.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), colX.price, tableY + (rowH / 2) - 4, { width: colW.price - 6, align: 'right' });

        // 6. Amount without GST
        doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5);
        doc.text(lineTaxableAmount.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), colX.amount, tableY + (rowH / 2) - 4, { width: colW.amount - 6, align: 'right' });

        tableY += rowH;
      });

      // Totals
      const subtotalVal = Number(order.subtotal) || calculatedTaxableSubtotal;
      const taxVal = Number(order.taxTotal) || (subtotalVal * 0.18);
      const shippingVal = Number(order.shippingCharges) || 0;
      const discountVal = Number(order.discountTotal) || 0;
      const finalAmountVal = Number(order.finalAmount) || (subtotalVal + taxVal + shippingVal - discountVal);

      const sumTop = tableY + 10;
      // Left Box: Verification
      doc.roundedRect(40, sumTop, 240, 72, 3).strokeColor('#cbd5e1').lineWidth(0.8).stroke();
      doc.fillColor('#0284c7').font('Helvetica-Bold').fontSize(7.5).text('DISPATCH & TRANSPORT VERIFICATION', 48, sumTop + 8);
      doc.fillColor('#334155').font('Helvetica').fontSize(7);
      doc.text(`• Consignment dispatched through ${transportName} to ${bookingStation} booking point.`, 48, sumTop + 22, { width: 224 });
      doc.text(`• Package verified with inspection seal as per instruction note.`, 48, sumTop + 36, { width: 224 });
      doc.text(`• All components packed under factory inspection standards.`, 48, sumTop + 50, { width: 224 });

      // Right Side: Totals
      let rightTotalsY = sumTop + 2;
      doc.fillColor('#475569').font('Helvetica').fontSize(8).text('Total Units Shipped:', 295, rightTotalsY);
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5).text(`${totalUnits.toFixed(2)} PCS`, 425, rightTotalsY, { width: 130, align: 'right' });
      rightTotalsY += 13;

      doc.fillColor('#475569').font('Helvetica').fontSize(8).text('Subtotal (Taxable Value):', 295, rightTotalsY);
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5).text(`Rs. ${subtotalVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rightTotalsY, { width: 130, align: 'right' });
      rightTotalsY += 13;

      const invTaxRate1 = order.taxRate !== undefined && order.taxRate !== null ? Number(order.taxRate) : 18.0;
      doc.fillColor('#0369a1').font('Helvetica-Bold').fontSize(8).text(`Taxes / GST (${invTaxRate1}%):`, 295, rightTotalsY);
      doc.fillColor('#0369a1').font('Helvetica-Bold').fontSize(8.5).text(`Rs. ${taxVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rightTotalsY, { width: 130, align: 'right' });
      rightTotalsY += 13;

      if (shippingVal > 0) {
        doc.fillColor('#475569').font('Helvetica').fontSize(8).text('Shipping Charges:', 295, rightTotalsY);
        doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5).text(`Rs. ${shippingVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rightTotalsY, { width: 130, align: 'right' });
        rightTotalsY += 13;
      }

      if (discountVal > 0) {
        doc.fillColor('#16a34a').font('Helvetica').fontSize(8).text('Discount / Concession:', 295, rightTotalsY);
        doc.fillColor('#16a34a').font('Helvetica-Bold').fontSize(8.5).text(`- Rs. ${discountVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rightTotalsY, { width: 130, align: 'right' });
        rightTotalsY += 13;
      }

      // Total Payable Dark Box
      doc.rect(295, rightTotalsY + 2, 260, 24).fill('#0f172a');
      doc.fillColor('#ffffff').font('Helvetica-Bold').fontSize(8.5).text('Total Amount Payable:', 305, rightTotalsY + 9);
      doc.fontSize(10).text(`Rs. ${finalAmountVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 420, rightTotalsY + 8, { width: 125, align: 'right' });

      // Signatory
      const sigY = rightTotalsY + 38;
      doc.moveTo(420, sigY).lineTo(555, sigY).strokeColor('#94a3b8').lineWidth(0.8).stroke();
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8).text('Authorized Signatory', 420, sigY + 4, { width: 135, align: 'center' });
      doc.fillColor('#64748b').font('Helvetica').fontSize(7.5).text('Grand Aqua Solutions', 420, sigY + 14, { width: 135, align: 'center' });

      // Bottom footer
      doc.fillColor('#94a3b8').font('Helvetica').fontSize(7.5);
      doc.text(`Tax Invoice: ${invoiceNumber} | ${buyerName} | Template 1 (Modern)`, 40, 775, { lineBreak: false });
      doc.text('Page 1 of 1', 40, 775, { width: 515, align: 'right', lineBreak: false });

      doc.end();
    });
  }

  // ==========================================
  // TEMPLATE 2: EXECUTIVE CLEAN MINIMAL (EMERALD)
  // ==========================================
  private generateQuotationTemplate2(quotation: any, imageBuffers: (Buffer | null)[]): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      const doc = new (PDFDocument as any)({ margin: 40, size: 'A4' });
      const buffers: Buffer[] = [];
      doc.on('data', buffers.push.bind(buffers));
      doc.on('end', () => resolve(Buffer.concat(buffers)));
      doc.on('error', (err: any) => reject(err));

      const items = quotation.items || [];

      // Minimalist Header: Left logo, Right Emerald Badge
      const logo = this.getOfficialLogoPath();
      if (logo) {
        try { doc.image(logo, 40, 42, { fit: [140, 50] }); } catch {}
      } else {
        doc.fillColor('#0f172a').fontSize(18).font('Helvetica-Bold').text('GRAND AQUA', 40, 45);
        doc.fontSize(8.5).font('Helvetica').fillColor('#64748b').text('Pure • Safe • Healthy RO Systems', 40, 68);
      }

      // Right Pill Badge
      doc.roundedRect(365, 40, 190, 55, 6).fillAndStroke('#f0fdf4', '#bbf7d0');
      doc.fillColor('#047857').font('Helvetica-Bold').fontSize(11).text('COMMERCIAL QUOTE', 375, 48);
      doc.fillColor('#334155').font('Helvetica').fontSize(8);
      doc.text(`Ref: ${quotation.quotationNumber || 'GA-QT-2026'}`, 375, 63);
      doc.text(`Date: ${new Date(quotation.createdAt || Date.now()).toLocaleDateString('en-GB')}`, 375, 75);
      doc.text(`Valid: ${new Date(quotation.validUntil || Date.now()).toLocaleDateString('en-GB')}`, 465, 75);

      // Company info line
      doc.fillColor('#64748b').font('Helvetica').fontSize(7.5).text(
        'Grand Aqua Solutions Pvt Ltd  •  GSTIN: 07AAAAA0000A1Z5  •  Support: +91 98765 43210  •  sales@grandaqua.com',
        40, 102
      );
      doc.moveTo(40, 114).lineTo(555, 114).strokeColor('#e2e8f0').lineWidth(0.8).stroke();

      // Client info 2 boxes
      const clientY = 122;
      doc.roundedRect(40, clientY, 250, 60, 4).fillAndStroke('#f8fafc', '#e2e8f0');
      doc.fillColor('#047857').font('Helvetica-Bold').fontSize(7.5).text('PREPARED FOR (PROSPECTIVE BUYER)', 48, clientY + 7);
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(9).text(
        quotation.buyer?.businessName || quotation.buyer?.user?.fullName || 'Valued Client',
        48, clientY + 20, { width: 232, ellipsis: true }
      );
      doc.fillColor('#475569').font('Helvetica').fontSize(8).text(
        `Tier: ${quotation.buyer?.loyaltyTier || 'DIAMOND'}  •  Type: ${quotation.buyer?.buyerType || 'Wholesale'}\nMobile: ${quotation.buyer?.user?.phone || 'N/A'}  •  GSTIN: ${quotation.buyer?.gstin || 'Retail / Unregistered'}`,
        48, clientY + 34
      );

      doc.roundedRect(305, clientY, 250, 60, 4).fillAndStroke('#f8fafc', '#e2e8f0');
      doc.fillColor('#047857').font('Helvetica-Bold').fontSize(7.5).text('QUOTATION PARAMETERS', 313, clientY + 7);
      doc.fillColor('#334155').font('Helvetica').fontSize(8).text(
        `• Status: ${quotation.status || 'PENDING_APPROVAL'}\n• Payment Terms: Payment on Delivery / Trade Credit\n• Guarantee: 1-Year Comprehensive Internal Parts\n• Pricing: Exclusive Wholesale Commercial Rate`,
        313, clientY + 20
      );

      // Table layout
      let tableY = 192;
      const colX = { num: 40, img: 64, prod: 114, qty: 310, price: 375, total: 455 };
      const colW = { num: 24, img: 50, prod: 196, qty: 65, price: 80, total: 100 };

      const drawHeader = (currY: number) => {
        doc.roundedRect(40, currY, 515, 20, 3).fill('#f1f5f9');
        doc.fillColor('#334155').fontSize(7.5).font('Helvetica-Bold');
        doc.text('#', colX.num, currY + 6, { width: colW.num, align: 'center' });
        doc.text('IMAGE', colX.img, currY + 6, { width: colW.img, align: 'center' });
        doc.text('ITEM & SPECIFICATION', colX.prod + 6, currY + 6, { width: colW.prod - 12 });
        doc.text('QUANTITY', colX.qty, currY + 6, { width: colW.qty, align: 'center' });
        doc.text('RATE (INR)', colX.price, currY + 6, { width: colW.price - 6, align: 'right' });
        doc.text('TAXABLE TOTAL', colX.total, currY + 6, { width: colW.total - 6, align: 'right' });
      };

      drawHeader(tableY);
      tableY += 20;

      let totalUnits = 0;
      let calculatedTaxableSubtotal = 0;
      const rowHeight = 44;

      items.forEach((item: any, idx: number) => {
        if (tableY + rowHeight > 690) {
          doc.addPage();
          tableY = 40;
          drawHeader(tableY);
          tableY += 20;
        }

        doc.rect(40, tableY, 515, rowHeight).strokeColor('#e2e8f0').lineWidth(0.5).stroke();
        const qty = Number(item.quantity) || 1;
        const price = Number(item.unitPrice) || 0;
        const lineTaxableTotal = qty * price;
        totalUnits += qty;
        calculatedTaxableSubtotal += lineTaxableTotal;

        const rawTitle = (item.productName || item.product?.name || 'Water Purifier').trim();
        const sku = (item.sku || item.product?.sku || '').trim();
        let cleanTitle = rawTitle;
        if (sku && cleanTitle.includes(`(${sku})`)) {
          cleanTitle = cleanTitle.replace(`(${sku})`, '').trim();
        }
        const modelStr = sku ? `Model: ${sku}` : (item.product?.category?.name || 'Standard RO');

        // 1. #
        doc.fillColor('#64748b').font('Helvetica').fontSize(8);
        doc.text(`${idx + 1}`, colX.num, tableY + (rowHeight / 2) - 4, { width: colW.num, align: 'center' });

        // 2. Image
        const img = imageBuffers[idx];
        const imgSize = 32;
        const imgX = colX.img + (colW.img - imgSize) / 2;
        const imgY = tableY + (rowHeight - imgSize) / 2;
        if (img) {
          try {
            doc.roundedRect(imgX - 2, imgY - 2, imgSize + 4, imgSize + 4, 3).fillAndStroke('#ffffff', '#cbd5e1');
            doc.image(img, imgX, imgY, { fit: [imgSize, imgSize], align: 'center', valign: 'center' });
          } catch {
            this.drawCameraPlaceholder(doc, colX.img + colW.img / 2, tableY + rowHeight / 2);
          }
        } else {
          this.drawCameraPlaceholder(doc, colX.img + colW.img / 2, tableY + rowHeight / 2);
        }

        // 3. Product
        doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5);
        doc.text(cleanTitle, colX.prod + 6, tableY + 8, { width: colW.prod - 12, height: 13, ellipsis: true });
        doc.fillColor('#059669').font('Helvetica-Bold').fontSize(7.5);
        doc.text(modelStr, colX.prod + 6, tableY + 24, { width: colW.prod - 12, height: 11, ellipsis: true });

        // 4. Qty
        doc.fillColor('#0f172a').font('Helvetica').fontSize(8);
        doc.text(`${qty.toFixed(2)} PCS`, colX.qty, tableY + (rowHeight / 2) - 4, { width: colW.qty, align: 'center' });

        // 5. Rate
        doc.text(price.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), colX.price, tableY + (rowHeight / 2) - 4, { width: colW.price - 6, align: 'right' });

        // 6. Taxable Total (without GST)
        doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5);
        doc.text(lineTaxableTotal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), colX.total, tableY + (rowHeight / 2) - 4, { width: colW.total - 6, align: 'right' });

        tableY += rowHeight;
      });

      // Bottom Row Total
      doc.roundedRect(40, tableY, 515, 22, 2).fill('#f8fafc');
      doc.roundedRect(40, tableY, 515, 22, 2).strokeColor('#cbd5e1').lineWidth(0.6).stroke();
      doc.fillColor('#334155').font('Helvetica-Bold').fontSize(8.5);
      doc.text('Net Taxable Total', colX.num, tableY + 6, { width: colX.total - colX.num - 10, align: 'right' });
      doc.text(`Rs. ${calculatedTaxableSubtotal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, colX.total, tableY + 6, { width: colW.total - 6, align: 'right' });
      tableY += 30;

      // Bottom Section: Left Banking, Right Totals
      const subtotalVal = Number(quotation.subtotal) || calculatedTaxableSubtotal;
      const taxVal = Number(quotation.taxAmount) || (subtotalVal * 0.18);
      const discountVal = Number(quotation.additionalDiscountApproved) || 0;
      const shippingVal = Number(quotation.shippingCharges) || 0;
      const finalTotalVal = Number(quotation.finalTotal) || (subtotalVal + taxVal + shippingVal - discountVal);

      // Left Bank Card
      doc.roundedRect(40, tableY, 240, 72, 4).fillAndStroke('#f0fdf4', '#bbf7d0');
      doc.fillColor('#047857').font('Helvetica-Bold').fontSize(7.5).text('OFFICIAL BANKING & REMITTANCE', 48, tableY + 8);
      doc.fillColor('#334155').font('Helvetica').fontSize(7.5);
      doc.text('Beneficiary: Grand Aqua Solutions Pvt Ltd\nBank: HDFC Bank  |  Branch: Industrial Hub\nA/C No: 50200088992211\nIFSC Code: HDFC0001234  |  UPI: grandaqua@hdfc', 48, tableY + 22);

      // Right Totals
      let rY = tableY + 2;
      doc.fillColor('#475569').font('Helvetica').fontSize(8).text('Subtotal (Taxable Value):', 295, rY);
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5).text(`Rs. ${subtotalVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rY, { width: 130, align: 'right' });
      rY += 13;

      const qTaxRate2 = quotation.taxRate !== undefined && quotation.taxRate !== null ? Number(quotation.taxRate) : 0;
      if (qTaxRate2 === 0) {
        doc.fillColor('#059669').font('Helvetica-Bold').fontSize(8).text('GST Tax Status:', 295, rY);
        doc.fillColor('#059669').font('Helvetica-Bold').fontSize(7.5).text('Applicable on Approval (5%–18%)', 390, rY, { width: 165, align: 'right' });
      } else {
        doc.fillColor('#059669').font('Helvetica-Bold').fontSize(8).text(`Taxes / GST (${qTaxRate2}%):`, 295, rY);
        doc.fillColor('#059669').font('Helvetica-Bold').fontSize(8.5).text(`Rs. ${taxVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rY, { width: 130, align: 'right' });
      }
      rY += 13;

      if (discountVal > 0) {
        doc.fillColor('#16a34a').font('Helvetica-Bold').fontSize(8).text('Special Concession:', 295, rY);
        doc.fillColor('#16a34a').font('Helvetica-Bold').fontSize(8.5).text(`- Rs. ${discountVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rY, { width: 130, align: 'right' });
        rY += 13;
      }

      if (shippingVal > 0) {
        doc.fillColor('#475569').font('Helvetica').fontSize(8).text('Freight Charges:', 295, rY);
        doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5).text(`Rs. ${shippingVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rY, { width: 130, align: 'right' });
        rY += 13;
      }

      // Emerald Highlight Box
      doc.roundedRect(295, rY + 2, 260, 24, 4).fill('#059669');
      doc.fillColor('#ffffff').font('Helvetica-Bold').fontSize(8.5).text('Final Payable Total:', 305, rY + 8);
      doc.fontSize(10).text(`Rs. ${finalTotalVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 420, rY + 7, { width: 125, align: 'right' });

      // Signatory
      const sigY = rY + 38;
      doc.moveTo(420, sigY).lineTo(555, sigY).strokeColor('#94a3b8').lineWidth(0.8).stroke();
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8).text('Authorized Signatory', 420, sigY + 4, { width: 135, align: 'center' });
      doc.fillColor('#64748b').font('Helvetica').fontSize(7.5).text('Grand Aqua Commercial Division', 420, sigY + 14, { width: 135, align: 'center' });

      // Footer
      doc.fillColor('#94a3b8').font('Helvetica').fontSize(7.5);
      doc.text(`Quotation: ${quotation.quotationNumber || 'GA-QT-2026'} | Template 2 (Executive Minimal)`, 40, 775, { lineBreak: false });
      doc.text('Page 1 of 1', 40, 775, { width: 515, align: 'right', lineBreak: false });

      doc.end();
    });
  }

  private generateInvoiceTemplate2(order: any, invoice: any, imageBuffers: (Buffer | null)[]): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      const doc = new (PDFDocument as any)({ margin: 40, size: 'A4' });
      const buffers: Buffer[] = [];
      doc.on('data', buffers.push.bind(buffers));
      doc.on('end', () => resolve(Buffer.concat(buffers)));
      doc.on('error', (err: any) => reject(err));

      const items = order.items || [];
      const rawInvNum = invoice?.invoiceNumber || order.invoices?.[0]?.invoiceNumber || order.orderNumber || '1063';
      let cleanDigits = rawInvNum.toString().replace(/[^0-9]/g, '');
      if (cleanDigits.length > 4) cleanDigits = cleanDigits.slice(-4);
      const invoiceNumber = `INV-2026-${cleanDigits.padStart(4, '0')}`;
      const invoiceDate = invoice?.invoiceDate
        ? new Date(invoice.invoiceDate).toLocaleDateString('en-GB')
        : new Date(order.createdAt || Date.now()).toLocaleDateString('en-GB');

      const buyerName = order.buyer?.businessName || order.buyer?.user?.fullName || 'Valued Buyer';
      const buyerPhone = order.buyer?.user?.phone || order.buyer?.user?.mobileNumber || '9847032612';
      const buyerGstin = order.buyer?.gstin || '32BMTPC7034C1ZD';

      let buyerAddress = 'Thathamangalam, Palakkad, Kerala, India - 678531';
      let bookingStation = 'Palakkad';
      let transportName = 'Keraleeya Surface Logistics';

      if (order.shippingAddress && typeof order.shippingAddress === 'object') {
        const addr = order.shippingAddress;
        buyerAddress = [addr.addressLine || addr.address, addr.city || addr.district, addr.state || 'Kerala', addr.pinCode || addr.postalCode].filter(Boolean).join(', ');
        bookingStation = addr.city || addr.district || bookingStation;
      }
      if (order.transportDetails && typeof order.transportDetails === 'object') {
        transportName = order.transportDetails.transporterName || order.transportDetails.carrier || transportName;
      }

      // Minimalist Header: Left logo, Right Emerald Badge
      const logo = this.getOfficialLogoPath();
      if (logo) {
        try { doc.image(logo, 40, 42, { fit: [140, 50] }); } catch {}
      } else {
        doc.fillColor('#0f172a').fontSize(18).font('Helvetica-Bold').text('GRAND AQUA', 40, 45);
        doc.fontSize(8.5).font('Helvetica').fillColor('#64748b').text('Pure • Safe • Healthy RO Systems', 40, 68);
      }

      // Right Pill Badge
      doc.roundedRect(365, 40, 190, 55, 6).fillAndStroke('#f0fdf4', '#bbf7d0');
      doc.fillColor('#047857').font('Helvetica-Bold').fontSize(11).text('TAX INVOICE', 375, 48);
      doc.fillColor('#334155').font('Helvetica').fontSize(8);
      doc.text(`Invoice: ${invoiceNumber}`, 375, 63);
      doc.text(`Date: ${invoiceDate}`, 375, 75);
      doc.text(`Order: #${order.orderNumber || 'GA-ORD'}`, 465, 75);

      // Company info line
      doc.fillColor('#64748b').font('Helvetica').fontSize(7.5).text(
        'Grand Aqua Solutions Pvt Ltd  •  GSTIN: 07AAAAA0000A1Z5  •  Support: +91 98765 43210  •  www.grandaqua.com',
        40, 102
      );
      doc.moveTo(40, 114).lineTo(555, 114).strokeColor('#e2e8f0').lineWidth(0.8).stroke();

      // Billed To & Shipped To cards
      const clientY = 122;
      doc.roundedRect(40, clientY, 250, 60, 4).fillAndStroke('#f8fafc', '#e2e8f0');
      doc.fillColor('#047857').font('Helvetica-Bold').fontSize(7.5).text('BILLED TO (BUYER DETAILS)', 48, clientY + 7);
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(9).text(buyerName, 48, clientY + 20, { width: 232, ellipsis: true });
      doc.fillColor('#475569').font('Helvetica').fontSize(8).text(
        `GSTIN: ${buyerGstin}  •  Mob: ${buyerPhone}\nAddress: ${buyerAddress}`,
        48, clientY + 34, { width: 232, height: 22, ellipsis: true }
      );

      doc.roundedRect(305, clientY, 250, 60, 4).fillAndStroke('#f8fafc', '#e2e8f0');
      doc.fillColor('#047857').font('Helvetica-Bold').fontSize(7.5).text('SHIPPING & LOGISTICS', 313, clientY + 7);
      doc.fillColor('#334155').font('Helvetica').fontSize(8).text(
        `• Destination Hub: ${bookingStation}\n• Logistics Partner: ${transportName}\n• Payment Terms: ${order.paymentTerms || 'Payment on Delivery'}\n• Consignment Verification: Factory Inspected & Sealed`,
        313, clientY + 20
      );

      // Table layout
      let tableY = 192;
      const colX = { num: 40, img: 62, prod: 112, qty: 305, price: 370, amount: 455 };
      const colW = { num: 22, img: 50, prod: 193, qty: 65, price: 85, amount: 100 };

      const drawHeader = (currY: number) => {
        doc.roundedRect(40, currY, 515, 20, 3).fill('#f1f5f9');
        doc.fillColor('#334155').fontSize(7.5).font('Helvetica-Bold');
        doc.text('#', colX.num, currY + 6, { width: colW.num, align: 'center' });
        doc.text('IMAGE', colX.img, currY + 6, { width: colW.img, align: 'center' });
        doc.text('PRODUCT & SPECIFICATION', colX.prod + 6, currY + 6, { width: colW.prod - 12 });
        doc.text('QUANTITY', colX.qty, currY + 6, { width: colW.qty, align: 'center' });
        doc.text('UNIT PRICE (INR)', colX.price, currY + 6, { width: colW.price - 6, align: 'right' });
        doc.text('AMOUNT (INR)', colX.amount, currY + 6, { width: colW.amount - 6, align: 'right' });
      };

      drawHeader(tableY);
      tableY += 20;

      let totalUnits = 0;
      let calculatedTaxableSubtotal = 0;
      const rowH = 44;

      items.forEach((item: any, idx: number) => {
        if (tableY + rowH > 680) {
          doc.addPage();
          tableY = 40;
          drawHeader(tableY);
          tableY += 20;
        }

        doc.rect(40, tableY, 515, rowH).strokeColor('#e2e8f0').lineWidth(0.5).stroke();
        const qty = Number(item.quantity) || 1;
        const price = Number(item.unitPrice) || 0;
        const lineTaxableAmount = qty * price;
        totalUnits += qty;
        calculatedTaxableSubtotal += lineTaxableAmount;

        const rawTitle = (item.productName || item.product?.name || 'Water Purifier').trim();
        const sku = (item.sku || item.product?.sku || '').trim();
        let cleanTitle = rawTitle;
        if (sku && cleanTitle.includes(`(${sku})`)) {
          cleanTitle = cleanTitle.replace(`(${sku})`, '').trim();
        }
        const modelStr = sku ? `Model: ${sku}` : (item.product?.category?.name || 'Standard RO');

        // 1. #
        doc.fillColor('#64748b').font('Helvetica').fontSize(8);
        doc.text(`${idx + 1}`, colX.num, tableY + (rowH / 2) - 4, { width: colW.num, align: 'center' });

        // 2. Image
        const imgBuffer = imageBuffers[idx];
        const imgSize = 32;
        const imgX = colX.img + (colW.img - imgSize) / 2;
        const imgY = tableY + (rowH - imgSize) / 2;
        if (imgBuffer) {
          try {
            doc.roundedRect(imgX - 2, imgY - 2, imgSize + 4, imgSize + 4, 3).fillAndStroke('#ffffff', '#cbd5e1');
            doc.image(imgBuffer, imgX, imgY, { fit: [imgSize, imgSize], align: 'center', valign: 'center' });
          } catch {
            this.drawCameraPlaceholder(doc, colX.img + colW.img / 2, tableY + rowH / 2);
          }
        } else {
          this.drawCameraPlaceholder(doc, colX.img + colW.img / 2, tableY + rowH / 2);
        }

        // 3. Product & Spec
        doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5);
        doc.text(cleanTitle, colX.prod + 6, tableY + 8, { width: colW.prod - 12, height: 13, ellipsis: true });
        doc.fillColor('#059669').font('Helvetica-Bold').fontSize(7.5);
        doc.text(modelStr, colX.prod + 6, tableY + 24, { width: colW.prod - 12, height: 11, ellipsis: true });

        // 4. Qty
        doc.fillColor('#0f172a').font('Helvetica').fontSize(8);
        doc.text(`${qty.toFixed(2)} PCS`, colX.qty, tableY + (rowH / 2) - 4, { width: colW.qty, align: 'center' });

        // 5. Unit Price
        doc.text(price.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), colX.price, tableY + (rowH / 2) - 4, { width: colW.price - 6, align: 'right' });

        // 6. Amount (without GST)
        doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5);
        doc.text(lineTaxableAmount.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), colX.amount, tableY + (rowH / 2) - 4, { width: colW.amount - 6, align: 'right' });

        tableY += rowH;
      });

      // Bottom Row Total
      doc.roundedRect(40, tableY, 515, 22, 2).fill('#f8fafc');
      doc.roundedRect(40, tableY, 515, 22, 2).strokeColor('#cbd5e1').lineWidth(0.6).stroke();
      doc.fillColor('#334155').font('Helvetica-Bold').fontSize(8.5);
      doc.text('Subtotal (Taxable Value)', colX.num, tableY + 6, { width: colX.amount - colX.num - 10, align: 'right' });
      doc.text(`Rs. ${calculatedTaxableSubtotal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, colX.amount, tableY + 6, { width: colW.amount - 6, align: 'right' });
      tableY += 30;

      // Bottom Totals
      const subtotalVal = Number(order.subtotal) || calculatedTaxableSubtotal;
      const taxVal = Number(order.taxTotal) || (subtotalVal * 0.18);
      const shippingVal = Number(order.shippingCharges) || 0;
      const discountVal = Number(order.discountTotal) || 0;
      const finalAmountVal = Number(order.finalAmount) || (subtotalVal + taxVal + shippingVal - discountVal);

      // Left Bank Card
      doc.roundedRect(40, tableY, 240, 72, 4).fillAndStroke('#f0fdf4', '#bbf7d0');
      doc.fillColor('#047857').font('Helvetica-Bold').fontSize(7.5).text('OFFICIAL BANKING & REMITTANCE', 48, tableY + 8);
      doc.fillColor('#334155').font('Helvetica').fontSize(7.5);
      doc.text('Beneficiary: Grand Aqua Solutions Pvt Ltd\nBank: HDFC Bank  |  Branch: Industrial Hub\nA/C No: 50200088992211\nIFSC Code: HDFC0001234  |  UPI: grandaqua@hdfc', 48, tableY + 22);

      // Right Totals
      let rY = tableY + 2;
      doc.fillColor('#475569').font('Helvetica').fontSize(8).text('Subtotal (Taxable Value):', 295, rY);
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5).text(`Rs. ${subtotalVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rY, { width: 130, align: 'right' });
      rY += 13;

      const invTaxRate2 = order.taxRate !== undefined && order.taxRate !== null ? Number(order.taxRate) : 18.0;
      doc.fillColor('#059669').font('Helvetica-Bold').fontSize(8).text(`Taxes / GST (${invTaxRate2}%):`, 295, rY);
      doc.fillColor('#059669').font('Helvetica-Bold').fontSize(8.5).text(`Rs. ${taxVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rY, { width: 130, align: 'right' });
      rY += 13;

      if (shippingVal > 0) {
        doc.fillColor('#475569').font('Helvetica').fontSize(8).text('Shipping Charges:', 295, rY);
        doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5).text(`Rs. ${shippingVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rY, { width: 130, align: 'right' });
        rY += 13;
      }

      if (discountVal > 0) {
        doc.fillColor('#16a34a').font('Helvetica').fontSize(8).text('Discount / Concession:', 295, rY);
        doc.fillColor('#16a34a').font('Helvetica-Bold').fontSize(8.5).text(`- Rs. ${discountVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rY, { width: 130, align: 'right' });
        rY += 13;
      }

      // Emerald Highlight Box
      doc.roundedRect(295, rY + 2, 260, 24, 4).fill('#059669');
      doc.fillColor('#ffffff').font('Helvetica-Bold').fontSize(8.5).text('Total Amount Payable:', 305, rY + 8);
      doc.fontSize(10).text(`Rs. ${finalAmountVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 420, rY + 7, { width: 125, align: 'right' });

      // Signatory
      const sigY = rY + 38;
      doc.moveTo(420, sigY).lineTo(555, sigY).strokeColor('#94a3b8').lineWidth(0.8).stroke();
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8).text('Authorized Signatory', 420, sigY + 4, { width: 135, align: 'center' });
      doc.fillColor('#64748b').font('Helvetica').fontSize(7.5).text('Grand Aqua Solutions', 420, sigY + 14, { width: 135, align: 'center' });

      // Footer
      doc.fillColor('#94a3b8').font('Helvetica').fontSize(7.5);
      doc.text(`Tax Invoice: ${invoiceNumber} | ${buyerName} | Template 2 (Executive Minimal)`, 40, 775, { lineBreak: false });
      doc.text('Page 1 of 1', 40, 775, { width: 515, align: 'right', lineBreak: false });

      doc.end();
    });
  }

  // ==========================================
  // TEMPLATE 3: FORMAL INDUSTRIAL GST WHOLESALE
  // ==========================================
  private generateQuotationTemplate3(quotation: any, imageBuffers: (Buffer | null)[]): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      const doc = new (PDFDocument as any)({ margin: 35, size: 'A4' });
      const buffers: Buffer[] = [];
      doc.on('data', buffers.push.bind(buffers));
      doc.on('end', () => resolve(Buffer.concat(buffers)));
      doc.on('error', (err: any) => reject(err));

      const items = quotation.items || [];

      // Formal double border frame
      doc.rect(35, 35, 525, 735).strokeColor('#1e3a8a').lineWidth(1.2).stroke();
      doc.rect(37.5, 37.5, 520, 730).strokeColor('#93c5fd').lineWidth(0.5).stroke();

      // Top title bar
      doc.rect(38, 38, 519, 22).fill('#1e3a8a');
      doc.fillColor('#ffffff').font('Helvetica-Bold').fontSize(9).text('COMMERCIAL QUOTATION / FORMAL ESTIMATE', 45, 44);
      doc.font('Helvetica').fontSize(8).text('GST REGISTERED WHOLESALE SUPPLY', 360, 44, { width: 190, align: 'right' });

      // Supplier Details Left & Logo Right
      doc.fillColor('#1e3a8a').fontSize(14).font('Helvetica-Bold').text('GRAND AQUA SOLUTIONS', 48, 66);
      doc.fillColor('#334155').fontSize(7.5).font('Helvetica');
      doc.text('Manufacturers & Distributors of Commercial & Domestic RO Water Systems', 48, 81);
      doc.text('Registered Office: Industrial Development Zone, Palakkad, Kerala - 678531', 48, 91);
      doc.font('Helvetica-Bold').text('GSTIN: 07AAAAA0000A1Z5   |   State Code: 32 (Kerala)   |   Ph: +91 98765 43210', 48, 101);

      const logo = this.getOfficialLogoPath();
      if (logo) {
        try { doc.image(logo, 455, 65, { fit: [95, 42] }); } catch {}
      }

      doc.moveTo(38, 114).lineTo(557, 114).strokeColor('#cbd5e1').lineWidth(0.8).stroke();

      // Formal 4-cell table for quote meta
      const gridY = 114;
      doc.rect(38, gridY, 260, 64).strokeColor('#cbd5e1').lineWidth(0.5).stroke();
      doc.rect(298, gridY, 259, 64).strokeColor('#cbd5e1').lineWidth(0.5).stroke();

      doc.fillColor('#1e3a8a').font('Helvetica-Bold').fontSize(7.5).text('DETAILS OF RECEIVER / BUYER:', 44, gridY + 6);
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5).text(
        quotation.buyer?.businessName || quotation.buyer?.user?.fullName || 'Valued Client',
        44, gridY + 18, { width: 248, ellipsis: true }
      );
      doc.fillColor('#334155').font('Helvetica').fontSize(7.5).text(
        `Category: ${quotation.buyer?.buyerType || 'Wholesale'}   Tier: ${quotation.buyer?.loyaltyTier || 'DIAMOND'}\nGSTIN / UIN: ${quotation.buyer?.gstin || 'Unregistered / Retail'}\nContact Number: ${quotation.buyer?.user?.phone || 'N/A'}`,
        44, gridY + 30
      );

      doc.fillColor('#1e3a8a').font('Helvetica-Bold').fontSize(7.5).text('QUOTATION & ESTIMATE PARTICULARS:', 304, gridY + 6);
      doc.fillColor('#334155').font('Helvetica').fontSize(7.5).text(
        `Quotation Number:  ${quotation.quotationNumber || 'GA-QT-2026'}\nIssue Date:  ${new Date(quotation.createdAt || Date.now()).toLocaleDateString('en-GB')}\nValid Until:  ${new Date(quotation.validUntil || Date.now()).toLocaleDateString('en-GB')}\nPayment Terms:  Approved Trade Credit / POD`,
        304, gridY + 18
      );

      // Table layout with HSN Code column!
      let tableY = 184;
      const colX = { num: 38, img: 60, prod: 108, hsn: 290, qty: 345, rate: 395, amount: 470 };
      const colW = { num: 22, img: 48, prod: 182, hsn: 55, qty: 50, rate: 75, amount: 87 };

      const drawHeader = (currY: number) => {
        doc.rect(38, currY, 519, 20).fill('#1e3a8a');
        doc.fillColor('#ffffff').fontSize(7).font('Helvetica-Bold');
        doc.text('#', colX.num, currY + 6, { width: colW.num, align: 'center' });
        doc.text('IMAGE', colX.img, currY + 6, { width: colW.img, align: 'center' });
        doc.text('DESCRIPTION OF GOODS', colX.prod + 4, currY + 6, { width: colW.prod - 8 });
        doc.text('HSN/SAC', colX.hsn, currY + 6, { width: colW.hsn, align: 'center' });
        doc.text('QUANTITY', colX.qty, currY + 6, { width: colW.qty, align: 'center' });
        doc.text('RATE (INR)', colX.rate, currY + 6, { width: colW.rate - 4, align: 'right' });
        doc.text('TAXABLE AMT', colX.amount, currY + 6, { width: colW.amount - 4, align: 'right' });
      };

      drawHeader(tableY);
      tableY += 20;

      let totalUnits = 0;
      let calculatedTaxableSubtotal = 0;
      const rowHeight = 44;

      items.forEach((item: any, idx: number) => {
        if (tableY + rowHeight > 680) {
          doc.addPage();
          tableY = 40;
          drawHeader(tableY);
          tableY += 20;
        }

        doc.rect(38, tableY, 519, rowHeight).strokeColor('#cbd5e1').lineWidth(0.5).stroke();
        const qty = Number(item.quantity) || 1;
        const price = Number(item.unitPrice) || 0;
        const lineTaxableTotal = qty * price;
        totalUnits += qty;
        calculatedTaxableSubtotal += lineTaxableTotal;

        const rawTitle = (item.productName || item.product?.name || 'Water Purifier').trim();
        const sku = (item.sku || item.product?.sku || '').trim();
        let cleanTitle = rawTitle;
        if (sku && cleanTitle.includes(`(${sku})`)) {
          cleanTitle = cleanTitle.replace(`(${sku})`, '').trim();
        }
        const modelStr = sku ? `Model: ${sku}` : (item.product?.category?.name || 'Standard RO');

        // Vertical dividers
        doc.moveTo(colX.img, tableY).lineTo(colX.img, tableY + rowHeight).strokeColor('#cbd5e1').stroke();
        doc.moveTo(colX.prod, tableY).lineTo(colX.prod, tableY + rowHeight).strokeColor('#cbd5e1').stroke();
        doc.moveTo(colX.hsn, tableY).lineTo(colX.hsn, tableY + rowHeight).strokeColor('#cbd5e1').stroke();
        doc.moveTo(colX.qty, tableY).lineTo(colX.qty, tableY + rowHeight).strokeColor('#cbd5e1').stroke();
        doc.moveTo(colX.rate, tableY).lineTo(colX.rate, tableY + rowHeight).strokeColor('#cbd5e1').stroke();
        doc.moveTo(colX.amount, tableY).lineTo(colX.amount, tableY + rowHeight).strokeColor('#cbd5e1').stroke();

        // 1. #
        doc.fillColor('#64748b').font('Helvetica').fontSize(8);
        doc.text(`${idx + 1}`, colX.num, tableY + (rowHeight / 2) - 4, { width: colW.num, align: 'center' });

        // 2. Image
        const img = imageBuffers[idx];
        const imgSize = 32;
        const imgX = colX.img + (colW.img - imgSize) / 2;
        const imgY = tableY + (rowHeight - imgSize) / 2;
        if (img) {
          try {
            doc.roundedRect(imgX - 2, imgY - 2, imgSize + 4, imgSize + 4, 3).fillAndStroke('#ffffff', '#cbd5e1');
            doc.image(img, imgX, imgY, { fit: [imgSize, imgSize], align: 'center', valign: 'center' });
          } catch {
            this.drawCameraPlaceholder(doc, colX.img + colW.img / 2, tableY + rowHeight / 2);
          }
        } else {
          this.drawCameraPlaceholder(doc, colX.img + colW.img / 2, tableY + rowHeight / 2);
        }

        // 3. Description
        doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5);
        doc.text(cleanTitle, colX.prod + 4, tableY + 8, { width: colW.prod - 8, height: 13, ellipsis: true });
        doc.fillColor('#1e3a8a').font('Helvetica-Bold').fontSize(7.5);
        doc.text(modelStr, colX.prod + 4, tableY + 24, { width: colW.prod - 8, height: 11, ellipsis: true });

        // 4. HSN Code
        doc.fillColor('#475569').font('Helvetica').fontSize(8);
        doc.text('84212190', colX.hsn, tableY + (rowHeight / 2) - 4, { width: colW.hsn, align: 'center' });

        // 5. Quantity
        doc.fillColor('#0f172a').font('Helvetica').fontSize(8);
        doc.text(`${qty.toFixed(2)} PCS`, colX.qty, tableY + (rowHeight / 2) - 4, { width: colW.qty, align: 'center' });

        // 6. Rate
        doc.text(price.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), colX.rate, tableY + (rowHeight / 2) - 4, { width: colW.rate - 4, align: 'right' });

        // 7. Amount without GST
        doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5);
        doc.text(lineTaxableTotal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), colX.amount, tableY + (rowHeight / 2) - 4, { width: colW.amount - 4, align: 'right' });

        tableY += rowHeight;
      });

      // Bottom Row Total of Table
      doc.rect(38, tableY, 519, 20).fill('#f8fafc');
      doc.rect(38, tableY, 519, 20).strokeColor('#cbd5e1').lineWidth(0.5).stroke();
      doc.fillColor('#1e3a8a').font('Helvetica-Bold').fontSize(8.5);
      doc.text('TOTAL TAXABLE VALUE', colX.num, tableY + 5, { width: colX.amount - colX.num - 10, align: 'right' });
      doc.text(`Rs. ${calculatedTaxableSubtotal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, colX.amount, tableY + 5, { width: colW.amount - 4, align: 'right' });
      tableY += 26;

      // GST TAX BREAKUP SECTION (Split into CGST + SGST)
      const subtotalVal = Number(quotation.subtotal) || calculatedTaxableSubtotal;
      const qTaxRate3 = quotation.taxRate !== undefined && quotation.taxRate !== null ? Number(quotation.taxRate) : 0;
      const taxVal = Number(quotation.taxAmount) || (qTaxRate3 > 0 ? (subtotalVal * qTaxRate3) / 100 : 0);
      const halfRate = (qTaxRate3 / 2).toFixed(1);
      const cgstVal = taxVal / 2;
      const sgstVal = taxVal / 2;
      const discountVal = Number(quotation.additionalDiscountApproved) || 0;
      const shippingVal = Number(quotation.shippingCharges) || 0;
      const finalTotalVal = Number(quotation.finalTotal) || (subtotalVal + taxVal + shippingVal - discountVal);

      // Left: GST Breakup Box
      doc.rect(38, tableY, 260, 78).strokeColor('#cbd5e1').lineWidth(0.5).stroke();
      doc.fillColor('#1e3a8a').font('Helvetica-Bold').fontSize(7.5).text('GST TAX DISTRIBUTION SCHEDULE', 44, tableY + 6);
      doc.fillColor('#334155').font('Helvetica').fontSize(7.5);

      if (qTaxRate3 === 0) {
        doc.text('• GST Status: Pending Super Admin Approval', 44, tableY + 20);
        doc.text('• Variable GST slab (5% – 18%) applies based on item class.', 44, tableY + 34);
        doc.text('• Statutory tax invoice issued post-approval.', 44, tableY + 48);
        doc.font('Helvetica-Bold').text('• Estimated Base Commercial Proposal (Excl. GST)', 44, tableY + 62);
      } else {
        doc.text(`• Central Tax (CGST @ ${halfRate}%):   Rs. ${cgstVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 44, tableY + 20);
        doc.text(`• State Tax (SGST @ ${halfRate}%):       Rs. ${sgstVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 44, tableY + 34);
        doc.text(`• Integrated Tax (IGST @ ${qTaxRate3.toFixed(1)}%): Applicable for Interstate`, 44, tableY + 48);
        doc.font('Helvetica-Bold').text(`• Total Tax Amount (${qTaxRate3}%):       Rs. ${taxVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 44, tableY + 62);
      }

      // Right: Final Amounts
      let rY = tableY + 2;
      doc.fillColor('#475569').font('Helvetica').fontSize(8).text('Subtotal (Taxable Value):', 305, rY);
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5).text(`Rs. ${subtotalVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rY, { width: 125, align: 'right' });
      rY += 13;

      if (qTaxRate3 === 0) {
        doc.fillColor('#1e3a8a').font('Helvetica-Bold').fontSize(8).text('GST Tax Status:', 305, rY);
        doc.fillColor('#1e3a8a').font('Helvetica-Bold').fontSize(7.5).text('Applicable on Approval (5%–18%)', 400, rY, { width: 150, align: 'right' });
      } else {
        doc.fillColor('#1e3a8a').font('Helvetica-Bold').fontSize(8).text(`Total GST Tax (${qTaxRate3}%):`, 305, rY);
        doc.fillColor('#1e3a8a').font('Helvetica-Bold').fontSize(8.5).text(`Rs. ${taxVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rY, { width: 125, align: 'right' });
      }
      rY += 13;

      if (discountVal > 0) {
        doc.fillColor('#16a34a').font('Helvetica-Bold').fontSize(8).text('Commercial Concession:', 305, rY);
        doc.fillColor('#16a34a').font('Helvetica-Bold').fontSize(8.5).text(`- Rs. ${discountVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rY, { width: 125, align: 'right' });
        rY += 13;
      }

      if (shippingVal > 0) {
        doc.fillColor('#475569').font('Helvetica').fontSize(8).text('Freight & Logistics:', 305, rY);
        doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5).text(`Rs. ${shippingVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rY, { width: 125, align: 'right' });
        rY += 13;
      }

      // Final Payable Formal Box
      doc.rect(305, rY + 2, 252, 24).fill('#1e3a8a');
      doc.fillColor('#ffffff').font('Helvetica-Bold').fontSize(8.5).text('Final Payable Total:', 315, rY + 8);
      doc.fontSize(10).text(`Rs. ${finalTotalVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 420, rY + 7, { width: 130, align: 'right' });

      // In Words & Signatory
      const bottomY = tableY + 84;
      doc.fillColor('#475569').font('Helvetica-Bold').fontSize(7.5).text('Amount in Words:', 38, bottomY);
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(7.5).text(this.numberToWords(finalTotalVal), 115, bottomY, { width: 280, ellipsis: true });

      const sigY = bottomY + 12;
      doc.moveTo(420, sigY + 28).lineTo(550, sigY + 28).strokeColor('#94a3b8').lineWidth(0.8).stroke();
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8).text('For GRAND AQUA SOLUTIONS', 415, sigY + 4, { width: 140, align: 'center' });
      doc.fillColor('#64748b').font('Helvetica').fontSize(7.5).text('Authorized Signatory', 415, sigY + 32, { width: 140, align: 'center' });

      doc.fillColor('#94a3b8').font('Helvetica').fontSize(7.5);
      doc.text(`Formal Quotation: ${quotation.quotationNumber || 'GA-QT-2026'} | Template 3 (GST Formal)`, 42, 755, { lineBreak: false });
      doc.text('Page 1 of 1', 42, 755, { width: 510, align: 'right', lineBreak: false });

      doc.end();
    });
  }

  private generateInvoiceTemplate3(order: any, invoice: any, imageBuffers: (Buffer | null)[]): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      const doc = new (PDFDocument as any)({ margin: 35, size: 'A4' });
      const buffers: Buffer[] = [];
      doc.on('data', buffers.push.bind(buffers));
      doc.on('end', () => resolve(Buffer.concat(buffers)));
      doc.on('error', (err: any) => reject(err));

      const items = order.items || [];
      const rawInvNum = invoice?.invoiceNumber || order.invoices?.[0]?.invoiceNumber || order.orderNumber || '1063';
      let cleanDigits = rawInvNum.toString().replace(/[^0-9]/g, '');
      if (cleanDigits.length > 4) cleanDigits = cleanDigits.slice(-4);
      const invoiceNumber = `INV-2026-${cleanDigits.padStart(4, '0')}`;
      const invoiceDate = invoice?.invoiceDate
        ? new Date(invoice.invoiceDate).toLocaleDateString('en-GB')
        : new Date(order.createdAt || Date.now()).toLocaleDateString('en-GB');

      const buyerName = order.buyer?.businessName || order.buyer?.user?.fullName || 'Valued Buyer';
      const buyerPhone = order.buyer?.user?.phone || order.buyer?.user?.mobileNumber || '9847032612';
      const buyerGstin = order.buyer?.gstin || '32BMTPC7034C1ZD';

      let buyerAddress = 'Thathamangalam, Palakkad, Kerala, India - 678531';
      let bookingStation = 'Palakkad';
      let transportName = 'Keraleeya Surface Logistics';

      if (order.shippingAddress && typeof order.shippingAddress === 'object') {
        const addr = order.shippingAddress;
        buyerAddress = [addr.addressLine || addr.address, addr.city || addr.district, addr.state || 'Kerala', addr.pinCode || addr.postalCode].filter(Boolean).join(', ');
        bookingStation = addr.city || addr.district || bookingStation;
      }
      if (order.transportDetails && typeof order.transportDetails === 'object') {
        transportName = order.transportDetails.transporterName || order.transportDetails.carrier || transportName;
      }

      // Formal double border frame
      doc.rect(35, 35, 525, 735).strokeColor('#1e3a8a').lineWidth(1.2).stroke();
      doc.rect(37.5, 37.5, 520, 730).strokeColor('#93c5fd').lineWidth(0.5).stroke();

      // Top bar: Tax Invoice under CGST Act
      doc.rect(38, 38, 519, 22).fill('#1e3a8a');
      doc.fillColor('#ffffff').font('Helvetica-Bold').fontSize(9).text('TAX INVOICE UNDER SECTION 31 OF CGST ACT, 2017', 45, 44);
      doc.font('Helvetica').fontSize(8).text('ORIGINAL FOR RECIPIENT', 360, 44, { width: 190, align: 'right' });

      // Company info Left & Logo Right
      doc.fillColor('#1e3a8a').fontSize(14).font('Helvetica-Bold').text('GRAND AQUA SOLUTIONS', 48, 66);
      doc.fillColor('#334155').fontSize(7.5).font('Helvetica');
      doc.text('Mfrs & Wholesale Distributors of Commercial, Industrial & Residential RO Systems', 48, 81);
      doc.text('Regd Office & Works: Industrial Development Plot, Palakkad, Kerala - 678531', 48, 91);
      doc.font('Helvetica-Bold').text('GSTIN: 07AAAAA0000A1Z5   |   State: Kerala (Code: 32)   |   Ph: +91 98765 43210', 48, 101);

      const logo = this.getOfficialLogoPath();
      if (logo) {
        try { doc.image(logo, 455, 65, { fit: [95, 42] }); } catch {}
      }

      doc.moveTo(38, 114).lineTo(557, 114).strokeColor('#cbd5e1').lineWidth(0.8).stroke();

      // 4-cell table for invoice particulars
      const gridY = 114;
      doc.rect(38, gridY, 260, 64).strokeColor('#cbd5e1').lineWidth(0.5).stroke();
      doc.rect(298, gridY, 259, 64).strokeColor('#cbd5e1').lineWidth(0.5).stroke();

      doc.fillColor('#1e3a8a').font('Helvetica-Bold').fontSize(7.5).text('DETAILS OF RECEIVER / BILLED TO:', 44, gridY + 6);
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5).text(buyerName, 44, gridY + 18, { width: 248, ellipsis: true });
      doc.fillColor('#334155').font('Helvetica').fontSize(7.5).text(
        `Address: ${buyerAddress}\nGSTIN / Unique ID: ${buyerGstin}\nContact Mobile: ${buyerPhone}`,
        44, gridY + 30, { width: 248, height: 26, ellipsis: true }
      );

      doc.fillColor('#1e3a8a').font('Helvetica-Bold').fontSize(7.5).text('TAX INVOICE & DISPATCH PARTICULARS:', 304, gridY + 6);
      doc.fillColor('#334155').font('Helvetica').fontSize(7.5).text(
        `Invoice Number:  ${invoiceNumber}\nInvoice Date:  ${invoiceDate}\nOrder Reference:  #${order.orderNumber || 'GA-ORD'}\nTransporter / Route:  ${transportName} (to ${bookingStation})`,
        304, gridY + 18
      );

      // Table layout with HSN Code column!
      let tableY = 184;
      const colX = { num: 38, img: 60, prod: 108, hsn: 290, qty: 345, rate: 395, amount: 470 };
      const colW = { num: 22, img: 48, prod: 182, hsn: 55, qty: 50, rate: 75, amount: 87 };

      const drawHeader = (currY: number) => {
        doc.rect(38, currY, 519, 20).fill('#1e3a8a');
        doc.fillColor('#ffffff').fontSize(7).font('Helvetica-Bold');
        doc.text('#', colX.num, currY + 6, { width: colW.num, align: 'center' });
        doc.text('IMAGE', colX.img, currY + 6, { width: colW.img, align: 'center' });
        doc.text('DESCRIPTION OF GOODS', colX.prod + 4, currY + 6, { width: colW.prod - 8 });
        doc.text('HSN/SAC', colX.hsn, currY + 6, { width: colW.hsn, align: 'center' });
        doc.text('QUANTITY', colX.qty, currY + 6, { width: colW.qty, align: 'center' });
        doc.text('RATE (INR)', colX.rate, currY + 6, { width: colW.rate - 4, align: 'right' });
        doc.text('TAXABLE AMT', colX.amount, currY + 6, { width: colW.amount - 4, align: 'right' });
      };

      drawHeader(tableY);
      tableY += 20;

      let totalUnits = 0;
      let calculatedTaxableSubtotal = 0;
      const rowH = 44;

      items.forEach((item: any, idx: number) => {
        if (tableY + rowH > 680) {
          doc.addPage();
          tableY = 40;
          drawHeader(tableY);
          tableY += 20;
        }

        doc.rect(38, tableY, 519, rowH).strokeColor('#cbd5e1').lineWidth(0.5).stroke();
        const qty = Number(item.quantity) || 1;
        const price = Number(item.unitPrice) || 0;
        const lineTaxableAmount = qty * price;
        totalUnits += qty;
        calculatedTaxableSubtotal += lineTaxableAmount;

        const rawTitle = (item.productName || item.product?.name || 'Water Purifier').trim();
        const sku = (item.sku || item.product?.sku || '').trim();
        let cleanTitle = rawTitle;
        if (sku && cleanTitle.includes(`(${sku})`)) {
          cleanTitle = cleanTitle.replace(`(${sku})`, '').trim();
        }
        const modelStr = sku ? `Model: ${sku}` : (item.product?.category?.name || 'Standard RO');

        // Vertical dividers
        doc.moveTo(colX.img, tableY).lineTo(colX.img, tableY + rowH).strokeColor('#cbd5e1').stroke();
        doc.moveTo(colX.prod, tableY).lineTo(colX.prod, tableY + rowH).strokeColor('#cbd5e1').stroke();
        doc.moveTo(colX.hsn, tableY).lineTo(colX.hsn, tableY + rowH).strokeColor('#cbd5e1').stroke();
        doc.moveTo(colX.qty, tableY).lineTo(colX.qty, tableY + rowH).strokeColor('#cbd5e1').stroke();
        doc.moveTo(colX.rate, tableY).lineTo(colX.rate, tableY + rowH).strokeColor('#cbd5e1').stroke();
        doc.moveTo(colX.amount, tableY).lineTo(colX.amount, tableY + rowH).strokeColor('#cbd5e1').stroke();

        // 1. #
        doc.fillColor('#64748b').font('Helvetica').fontSize(8);
        doc.text(`${idx + 1}`, colX.num, tableY + (rowH / 2) - 4, { width: colW.num, align: 'center' });

        // 2. Image
        const imgBuffer = imageBuffers[idx];
        const imgSize = 32;
        const imgX = colX.img + (colW.img - imgSize) / 2;
        const imgY = tableY + (rowH - imgSize) / 2;
        if (imgBuffer) {
          try {
            doc.roundedRect(imgX - 2, imgY - 2, imgSize + 4, imgSize + 4, 3).fillAndStroke('#ffffff', '#cbd5e1');
            doc.image(imgBuffer, imgX, imgY, { fit: [imgSize, imgSize], align: 'center', valign: 'center' });
          } catch {
            this.drawCameraPlaceholder(doc, colX.img + colW.img / 2, tableY + rowH / 2);
          }
        } else {
          this.drawCameraPlaceholder(doc, colX.img + colW.img / 2, tableY + rowH / 2);
        }

        // 3. Description
        doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5);
        doc.text(cleanTitle, colX.prod + 4, tableY + 8, { width: colW.prod - 8, height: 13, ellipsis: true });
        doc.fillColor('#1e3a8a').font('Helvetica-Bold').fontSize(7.5);
        doc.text(modelStr, colX.prod + 4, tableY + 24, { width: colW.prod - 8, height: 11, ellipsis: true });

        // 4. HSN Code
        doc.fillColor('#475569').font('Helvetica').fontSize(8);
        doc.text('84212190', colX.hsn, tableY + (rowH / 2) - 4, { width: colW.hsn, align: 'center' });

        // 5. Quantity
        doc.fillColor('#0f172a').font('Helvetica').fontSize(8);
        doc.text(`${qty.toFixed(2)} PCS`, colX.qty, tableY + (rowH / 2) - 4, { width: colW.qty, align: 'center' });

        // 6. Rate
        doc.text(price.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), colX.rate, tableY + (rowH / 2) - 4, { width: colW.rate - 4, align: 'right' });

        // 7. Amount without GST
        doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5);
        doc.text(lineTaxableAmount.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), colX.amount, tableY + (rowH / 2) - 4, { width: colW.amount - 4, align: 'right' });

        tableY += rowH;
      });

      // Bottom Row Total of Table
      doc.rect(38, tableY, 519, 20).fill('#f8fafc');
      doc.rect(38, tableY, 519, 20).strokeColor('#cbd5e1').lineWidth(0.5).stroke();
      doc.fillColor('#1e3a8a').font('Helvetica-Bold').fontSize(8.5);
      doc.text('TOTAL TAXABLE VALUE', colX.num, tableY + 5, { width: colX.amount - colX.num - 10, align: 'right' });
      doc.text(`Rs. ${calculatedTaxableSubtotal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, colX.amount, tableY + 5, { width: colW.amount - 4, align: 'right' });
      tableY += 26;

      // GST TAX BREAKUP SECTION (Split into CGST + SGST)
      const subtotalVal = Number(order.subtotal) || calculatedTaxableSubtotal;
      const invTaxRate3 = order.taxRate !== undefined && order.taxRate !== null ? Number(order.taxRate) : 18.0;
      const taxVal = Number(order.taxTotal) || ((subtotalVal * invTaxRate3) / 100);
      const halfRate = (invTaxRate3 / 2).toFixed(1);
      const cgstVal = taxVal / 2;
      const sgstVal = taxVal / 2;
      const shippingVal = Number(order.shippingCharges) || 0;
      const discountVal = Number(order.discountTotal) || 0;
      const finalAmountVal = Number(order.finalAmount) || (subtotalVal + taxVal + shippingVal - discountVal);

      // Left: GST Breakup Box
      doc.rect(38, tableY, 260, 78).strokeColor('#cbd5e1').lineWidth(0.5).stroke();
      doc.fillColor('#1e3a8a').font('Helvetica-Bold').fontSize(7.5).text('GST TAX DISTRIBUTION SCHEDULE', 44, tableY + 6);
      doc.fillColor('#334155').font('Helvetica').fontSize(7.5);
      doc.text(`• Central Tax (CGST @ ${halfRate}%):   Rs. ${cgstVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 44, tableY + 20);
      doc.text(`• State Tax (SGST @ ${halfRate}%):       Rs. ${sgstVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 44, tableY + 34);
      doc.text(`• Integrated Tax (IGST @ ${invTaxRate3.toFixed(1)}%): Applicable for Interstate`, 44, tableY + 48);
      doc.font('Helvetica-Bold').text(`• Total Tax Amount (${invTaxRate3}%):       Rs. ${taxVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 44, tableY + 62);

      // Right: Final Amounts
      let rY = tableY + 2;
      doc.fillColor('#475569').font('Helvetica').fontSize(8).text('Subtotal (Taxable Value):', 305, rY);
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5).text(`Rs. ${subtotalVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rY, { width: 125, align: 'right' });
      rY += 13;

      doc.fillColor('#1e3a8a').font('Helvetica-Bold').fontSize(8).text(`Total GST Tax (${invTaxRate3}%):`, 305, rY);
      doc.fillColor('#1e3a8a').font('Helvetica-Bold').fontSize(8.5).text(`Rs. ${taxVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rY, { width: 125, align: 'right' });
      rY += 13;

      if (shippingVal > 0) {
        doc.fillColor('#475569').font('Helvetica').fontSize(8).text('Shipping & Freight Charges:', 305, rY);
        doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8.5).text(`Rs. ${shippingVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rY, { width: 125, align: 'right' });
        rY += 13;
      }

      if (discountVal > 0) {
        doc.fillColor('#16a34a').font('Helvetica').fontSize(8).text('Commercial Concession:', 305, rY);
        doc.fillColor('#16a34a').font('Helvetica-Bold').fontSize(8.5).text(`- Rs. ${discountVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 425, rY, { width: 125, align: 'right' });
        rY += 13;
      }

      // Final Payable Formal Box
      doc.rect(305, rY + 2, 252, 24).fill('#1e3a8a');
      doc.fillColor('#ffffff').font('Helvetica-Bold').fontSize(8.5).text('Final Payable Total:', 315, rY + 8);
      doc.fontSize(10).text(`Rs. ${finalAmountVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`, 420, rY + 7, { width: 130, align: 'right' });

      // In Words & Signatory
      const bottomY = tableY + 84;
      doc.fillColor('#475569').font('Helvetica-Bold').fontSize(7.5).text('Amount in Words:', 38, bottomY);
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(7.5).text(this.numberToWords(finalAmountVal), 115, bottomY, { width: 280, ellipsis: true });

      const sigY = bottomY + 12;
      doc.moveTo(420, sigY + 28).lineTo(550, sigY + 28).strokeColor('#94a3b8').lineWidth(0.8).stroke();
      doc.fillColor('#0f172a').font('Helvetica-Bold').fontSize(8).text('For GRAND AQUA SOLUTIONS', 415, sigY + 4, { width: 140, align: 'center' });
      doc.fillColor('#64748b').font('Helvetica').fontSize(7.5).text('Authorized Signatory', 415, sigY + 32, { width: 140, align: 'center' });

      doc.fillColor('#94a3b8').font('Helvetica').fontSize(7.5);
      doc.text(`Formal Tax Invoice: ${invoiceNumber} | ${buyerName} | Template 3 (GST Formal)`, 42, 755, { lineBreak: false });
      doc.text('Page 1 of 1', 42, 755, { width: 510, align: 'right', lineBreak: false });

      doc.end();
    });
  }
}
