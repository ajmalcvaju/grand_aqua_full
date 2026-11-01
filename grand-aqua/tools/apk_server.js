const http = require('http');
const fs = require('fs');
const path = require('path');

const apkDir = 'd:\\grand_aqua_full\\grand-aqua\\APKs';

const server = http.createServer((req, res) => {
  const url = req.url.split('?')[0];

  const cleanUrl = url.toLowerCase();

  if (cleanUrl.startsWith('/samples/')) {
    const fileName = path.basename(url);
    const f = path.join(apkDir, 'samples', fileName);
    if (fs.existsSync(f)) {
      res.writeHead(200, {
        'Content-Type': 'application/pdf',
        'Content-Length': fs.statSync(f).size,
        'Content-Disposition': `inline; filename="${fileName}"`
      });
      return fs.createReadStream(f).pipe(res);
    }
  }

  if (cleanUrl === '/buyer' || cleanUrl === '/buyers' || cleanUrl === '/grand_aqua_buyer.apk' || cleanUrl.includes('buyer')) {
    const f = path.join(apkDir, 'Grand_Aqua_Buyer.apk');
    if (fs.existsSync(f)) {
      res.writeHead(200, {
        'Content-Type': 'application/vnd.android.package-archive',
        'Content-Length': fs.statSync(f).size,
        'Content-Disposition': 'attachment; filename=Grand_Aqua_Buyer.apk'
      });
      return fs.createReadStream(f).pipe(res);
    }
  }

  if (cleanUrl === '/admin' || cleanUrl === '/admins' || cleanUrl === '/grand_aqua_superadmin.apk' || cleanUrl.includes('admin')) {
    const f = path.join(apkDir, 'Grand_Aqua_SuperAdmin.apk');
    if (fs.existsSync(f)) {
      res.writeHead(200, {
        'Content-Type': 'application/vnd.android.package-archive',
        'Content-Length': fs.statSync(f).size,
        'Content-Disposition': 'attachment; filename=Grand_Aqua_SuperAdmin.apk'
      });
      return fs.createReadStream(f).pipe(res);
    }
  }

  if (cleanUrl === '/salesman' || cleanUrl === '/salesmen' || cleanUrl === '/grand_aqua_salesman.apk' || cleanUrl.includes('salesman')) {
    const f = path.join(apkDir, 'Grand_Aqua_Salesman.apk');
    if (fs.existsSync(f)) {
      res.writeHead(200, {
        'Content-Type': 'application/vnd.android.package-archive',
        'Content-Length': fs.statSync(f).size,
        'Content-Disposition': 'attachment; filename=Grand_Aqua_Salesman.apk'
      });
      return fs.createReadStream(f).pipe(res);
    }
  }

  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(`
    <!DOCTYPE html>
    <html>
    <head>
      <meta name='viewport' content='width=device-width, initial-scale=1'>
      <title>Grand Aqua Downloads</title>
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f8fafc; margin: 0; padding: 24px; color: #0f172a; text-align: center; }
        .card { max-width: 480px; margin: 0 auto; background: white; border-radius: 20px; padding: 28px; box-shadow: 0 4px 20px rgba(0,0,0,0.06); }
        .logo { width: 56px; height: 56px; border-radius: 16px; background: #0284c7; color: white; display: flex; align-items: center; justify-content: center; font-size: 28px; margin: 0 auto 16px; }
        h1 { font-size: 20px; font-weight: 800; margin: 0 0 6px; }
        p { font-size: 13px; color: #64748b; margin: 0 0 24px; }
        .btn { display: flex; align-items: center; justify-content: space-between; padding: 16px 20px; margin-bottom: 12px; background: #f0f9ff; border: 1.5px solid #bae6fd; border-radius: 14px; text-decoration: none; color: #0369a1; font-weight: 700; font-size: 15px; }
        .btn:hover { background: #e0f2fe; }
        .btn-sub { font-size: 11px; font-weight: 400; color: #64748b; display: block; margin-top: 2px; }
        .tag { font-size: 10px; background: #0284c7; color: white; padding: 4px 8px; border-radius: 8px; font-weight: 700; }
      </style>
    </head>
    <body>
      <div class='card'>
        <div class='logo'>💧</div>
        <h1>Grand Aqua App Downloads</h1>
        <p>Install or update the apps on your Android phone:</p>
        <a class='btn' href='/buyers'>
          <div style='text-align: left;'>
            <div>🛒 Grand Aqua Buyer App</div>
            <span class='btn-sub'>Catalog, Direct Orders & Quotations</span>
          </div>
          <span class='tag'>DOWNLOAD</span>
        </a>
        <a class='btn' href='/admin'>
          <div style='text-align: left;'>
            <div>👑 Grand Aqua Super Admin App</div>
            <span class='btn-sub'>Management, Approvals & Analytics</span>
          </div>
          <span class='tag'>DOWNLOAD</span>
        </a>
        <a class='btn' href='/salesman'>
          <div style='text-align: left;'>
            <div>👔 Grand Aqua Salesman App</div>
            <span class='btn-sub'>Field Sales, Buyer Orders & Targets</span>
          </div>
          <span class='tag'>DOWNLOAD</span>
        </a>

        <div style='margin-top: 32px; border-top: 1px solid #e2e8f0; padding-top: 20px; text-align: left;'>
          <h2 style='font-size: 15px; font-weight: 800; color: #0f172a; margin-bottom: 4px;'>📄 3 Official PDF Templates</h2>
          <p style='font-size: 12px; color: #64748b; margin-bottom: 16px;'>Preview new Invoice & Quotation printable designs:</p>

          <div style='font-size: 11px; font-weight: 700; color: #0284c7; text-transform: uppercase; margin-bottom: 8px;'>GST Tax Invoices</div>
          <a class='btn' style='padding: 12px 16px; margin-bottom: 8px;' href='/samples/Invoice_Template_1_Modern_Corporate.pdf' target='_blank'>
            <div>
              <div style='font-size: 13px;'>Template 1: Modern Corporate</div>
              <span class='btn-sub'>Navy banner • Centered images • Pre-tax subtotal</span>
            </div>
            <span class='tag' style='background: #0369a1;'>PREVIEW</span>
          </a>
          <a class='btn' style='padding: 12px 16px; margin-bottom: 8px;' href='/samples/Invoice_Template_2_Executive_Minimal.pdf' target='_blank'>
            <div>
              <div style='font-size: 13px;'>Template 2: Executive Clean Minimal</div>
              <span class='btn-sub'>Official logo • Slate table • NEFT Remittance</span>
            </div>
            <span class='tag' style='background: #059669;'>PREVIEW</span>
          </a>
          <a class='btn' style='padding: 12px 16px; margin-bottom: 16px;' href='/samples/Invoice_Template_3_GST_Formal_Wholesale.pdf' target='_blank'>
            <div>
              <div style='font-size: 13px;'>Template 3: GST Formal Wholesale</div>
              <span class='btn-sub'>Statutory double-border • HSN 84212190 • Tax schedule</span>
            </div>
            <span class='tag' style='background: #4338ca;'>PREVIEW</span>
          </a>

          <div style='font-size: 11px; font-weight: 700; color: #0284c7; text-transform: uppercase; margin-bottom: 8px;'>Commercial Quotations</div>
          <a class='btn' style='padding: 12px 16px; margin-bottom: 8px;' href='/samples/Quotation_Template_1_Modern_Corporate.pdf' target='_blank'>
            <div>
              <div style='font-size: 13px;'>Quotation T1: Modern Corporate</div>
              <span class='btn-sub'>Sky blue branding • Verification badge</span>
            </div>
            <span class='tag' style='background: #0369a1;'>PREVIEW</span>
          </a>
          <a class='btn' style='padding: 12px 16px; margin-bottom: 8px;' href='/samples/Quotation_Template_2_Executive_Minimal.pdf' target='_blank'>
            <div>
              <div style='font-size: 13px;'>Quotation T2: Executive Minimal</div>
              <span class='btn-sub'>Emerald badges • Bank card</span>
            </div>
            <span class='tag' style='background: #059669;'>PREVIEW</span>
          </a>
          <a class='btn' style='padding: 12px 16px; margin-bottom: 8px;' href='/samples/Quotation_Template_3_GST_Formal_Wholesale.pdf' target='_blank'>
            <div>
              <div style='font-size: 13px;'>Quotation T3: GST Formal Wholesale</div>
              <span class='btn-sub'>HSN 84212190 • Double border & words</span>
            </div>
            <span class='tag' style='background: #4338ca;'>PREVIEW</span>
          </a>
        </div>
      </div>
    </body>
    </html>
  `);
});

server.listen(8080, '0.0.0.0', () => {
  console.log('APK Server listening on http://0.0.0.0:8080');
});
