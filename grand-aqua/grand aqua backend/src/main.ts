import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AllExceptionsFilter } from './common/filters/http-exception.filter';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';
import { join } from 'path';
import * as fs from 'fs';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // Ensure uploads directory exists and serve statically
  const uploadDir = join(process.cwd(), 'uploads');
  if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
  }
  app.useStaticAssets(uploadDir, {
    prefix: '/uploads/',
  });

  // Request logging middleware
  app.use((req: any, res: any, next: any) => {
    console.log(`[HTTP ${new Date().toLocaleTimeString()}] ${req.method} ${req.originalUrl} from ${req.ip}`);
    next();
  });

  // Auto-route fallback: if client calls /auth/..., /products/..., /loyalty/... without /api/v1 prefix,
  // automatically rewrite to /api/v1/... so clients never get 404
  app.use((req: any, res: any, next: any) => {
    const p = (req.path || req.url || '').split('?')[0];
    const isSpecial =
      p.startsWith('/api/v1') ||
      p.startsWith('/uploads') ||
      p.startsWith('/samples') ||
      p.startsWith('/apks') ||
      p.startsWith('/download') ||
      p.startsWith('/buyer') ||
      p.startsWith('/admin') ||
      p.startsWith('/salesman') ||
      p === '/' ||
      p === '' ||
      p === '/health' ||
      p === '/ping' ||
      p === '/api';

    if (!isSpecial) {
      req.url = '/api/v1' + (req.url.startsWith('/') ? req.url : '/' + req.url);
    }
    next();
  });

  // Root & Health Landing Page (handles GET /, /api, /health, /ping, and direct APK downloads)
  app.use((req: any, res: any, next: any) => {
    const rawUrl = (req.path || req.url || '').split('?')[0].toLowerCase();
    const apkDir = join(process.cwd(), '..', 'APKs');

    // Serve sample PDFs
    if (rawUrl.startsWith('/samples/')) {
      const fileName = rawUrl.replace('/samples/', '');
      const filePath = join(apkDir, 'samples', fileName);
      if (fs.existsSync(filePath)) {
        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', `inline; filename="${fileName}"`);
        return fs.createReadStream(filePath).pipe(res);
      }
    }

    // Direct APK downloads
    if (rawUrl === '/buyer' || rawUrl === '/buyers' || rawUrl === '/grand_aqua_buyer.apk') {
      const apkPath = join(apkDir, 'Grand_Aqua_Buyer.apk');
      if (fs.existsSync(apkPath)) {
        res.setHeader('Content-Type', 'application/vnd.android.package-archive');
        res.setHeader('Content-Disposition', 'attachment; filename=Grand_Aqua_Buyer.apk');
        return fs.createReadStream(apkPath).pipe(res);
      }
    }

    if (rawUrl === '/admin' || rawUrl === '/admins' || rawUrl === '/grand_aqua_superadmin.apk' || rawUrl === '/grand_aqua_super_admin.apk') {
      const apkPath = join(apkDir, 'Grand_Aqua_SuperAdmin.apk');
      if (fs.existsSync(apkPath)) {
        res.setHeader('Content-Type', 'application/vnd.android.package-archive');
        res.setHeader('Content-Disposition', 'attachment; filename=Grand_Aqua_SuperAdmin.apk');
        return fs.createReadStream(apkPath).pipe(res);
      }
    }

    if (rawUrl === '/salesman' || rawUrl === '/salesmen' || rawUrl === '/grand_aqua_salesman.apk') {
      const apkPath = join(apkDir, 'Grand_Aqua_Salesman.apk');
      if (fs.existsSync(apkPath)) {
        res.setHeader('Content-Type', 'application/vnd.android.package-archive');
        res.setHeader('Content-Disposition', 'attachment; filename=Grand_Aqua_Salesman.apk');
        return fs.createReadStream(apkPath).pipe(res);
      }
    }

    // Full Mobile App Download Hub
    if (rawUrl === '/apks' || rawUrl === '/download' || rawUrl === '/downloads') {
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      return res.status(200).send(`
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Grand Aqua App Downloads</title>
          <style>
            * { box-sizing: border-box; }
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #f8fafc; margin: 0; padding: 24px 16px; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
            .card { max-width: 480px; width: 100%; margin: 0 auto; background: #1e293b; border: 1px solid #334155; border-radius: 24px; padding: 32px 24px; box-shadow: 0 20px 40px rgba(0,0,0,0.5); text-align: center; }
            .logo { width: 60px; height: 60px; border-radius: 18px; background: #0284c7; color: white; display: flex; align-items: center; justify-content: center; font-size: 30px; margin: 0 auto 16px; box-shadow: 0 4px 15px rgba(2, 132, 199, 0.4); }
            h1 { font-size: 22px; font-weight: 800; margin: 0 0 6px; color: #38bdf8; }
            p { font-size: 13px; color: #94a3b8; margin: 0 0 24px; line-height: 1.5; }
            .btn { display: flex; align-items: center; justify-content: space-between; padding: 16px 18px; margin-bottom: 12px; background: #334155; border: 1px solid #475569; border-radius: 16px; text-decoration: none; color: #f8fafc; font-weight: 700; font-size: 15px; transition: all 0.2s; }
            .btn:hover { background: #475569; transform: translateY(-1px); }
            .btn-sub { font-size: 12px; font-weight: 400; color: #94a3b8; display: block; margin-top: 3px; }
            .tag { font-size: 11px; background: #0284c7; color: white; padding: 6px 10px; border-radius: 8px; font-weight: 700; letter-spacing: 0.5px; }
            .btn-admin { border-color: #38bdf8; }
            .btn-admin .tag { background: #38bdf8; color: #0f172a; }
            .footer { margin-top: 24px; font-size: 12px; color: #64748b; }
          </style>
        </head>
        <body>
          <div class="card">
            <div class="logo">💧</div>
            <h1>Grand Aqua Mobile Apps</h1>
            <p>Click below to download and install the latest Android APKs on your phone:</p>
            
            <a class="btn" href="/buyers">
              <div style="text-align: left;">
                <div>🛒 Grand Aqua Buyer App</div>
                <span class="btn-sub">Catalog, 4-Tier Pricing &amp; GST Quotations</span>
              </div>
              <span class="tag">DOWNLOAD</span>
            </a>

            <a class="btn btn-admin" href="/admin">
              <div style="text-align: left;">
                <div>👑 Grand Aqua Super Admin App</div>
                <span class="btn-sub">Purchase Cost, Profit &amp; GST Approvals</span>
              </div>
              <span class="tag">DOWNLOAD</span>
            </a>

            <a class="btn" href="/salesman">
              <div style="text-align: left;">
                <div>👔 Grand Aqua Salesman App</div>
                <span class="btn-sub">Field Sales &amp; Target Management</span>
              </div>
              <span class="tag">DOWNLOAD</span>
            </a>

            <div style="margin-top: 24px; padding-top: 20px; border-top: 1px solid #334155;">
              <a class="btn" style="background: transparent; border-color: #0284c7; color: #38bdf8; justify-content: center;" href="http://192.168.29.44:3000">
                🖥️ Open Super Admin Web Dashboard
              </a>
            </div>

            <div class="footer">Grand Aqua v1.0.0 • Wi-Fi Server</div>
          </div>
        </body>
        </html>
      `);
    }

    if (rawUrl === '/' || rawUrl === '' || rawUrl === '/health' || rawUrl === '/ping' || rawUrl === '/api') {
      const acceptsHtml = req.headers['accept'] && req.headers['accept'].includes('text/html');
      if (acceptsHtml) {
        res.setHeader('Content-Type', 'text/html; charset=utf-8');
        return res.status(200).send(`
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>Grand Aqua Backend API - Online</title>
            <style>
              * { box-sizing: border-box; }
              body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #f8fafc; margin: 0; padding: 32px 16px; display: flex; align-items: center; justify-content: center; min-height: 100vh; }
              .card { background: #1e293b; border: 1px solid #334155; border-radius: 24px; padding: 36px 28px; max-width: 480px; width: 100%; box-shadow: 0 20px 40px rgba(0,0,0,0.5); text-align: center; }
              .badge { display: inline-flex; align-items: center; gap: 8px; background: rgba(34, 197, 94, 0.15); color: #4ade80; border: 1px solid rgba(34, 197, 94, 0.3); padding: 8px 16px; border-radius: 999px; font-size: 13px; font-weight: 700; margin-bottom: 24px; }
              .dot { width: 10px; height: 10px; background: #22c55e; border-radius: 50%; box-shadow: 0 0 10px #22c55e; display: inline-block; }
              h1 { font-size: 24px; font-weight: 800; margin: 0 0 10px; color: #38bdf8; }
              p { color: #94a3b8; font-size: 14px; margin: 0 0 24px; line-height: 1.5; }
              .links { display: flex; flex-direction: column; gap: 12px; }
              .btn { display: flex; align-items: center; justify-content: space-between; padding: 15px 18px; background: #334155; border: 1px solid #475569; border-radius: 14px; color: white; text-decoration: none; font-size: 14px; font-weight: 600; transition: all 0.2s; }
              .btn:hover { background: #475569; transform: translateY(-1px); }
              .btn-accent { background: #0284c7; border-color: #38bdf8; }
              .btn-accent:hover { background: #0369a1; }
              .footer { margin-top: 24px; font-size: 12px; color: #64748b; }
            </style>
          </head>
          <body>
            <div class="card">
              <div class="badge"><span class="dot"></span> SERVER ACTIVE &amp; RUNNING</div>
              <h1>💧 Grand Aqua Backend API</h1>
              <p>Grand Aqua REST API Server is active and operational on port 4000. All mobile apps and web dashboards are connected.</p>
              <div class="links">
                <a class="btn btn-accent" href="/apks">📱 Download Mobile Apps (APKs)</a>
                <a class="btn" href="http://192.168.29.44:3000">🖥️ Super Admin Web Dashboard</a>
                <a class="btn" href="/api/v1/docs">📚 API Swagger Documentation</a>
                <a class="btn" href="/api/v1">⚡ Base API JSON Endpoint</a>
              </div>
              <div class="footer">Grand Aqua v1.0.0 • MongoDB Connected</div>
            </div>
          </body>
          </html>
        `);
      }
      return res.status(200).json({
        success: true,
        statusCode: 200,
        status: 'online',
        message: 'Grand Aqua Unified Backend API is active and running',
        timestamp: new Date().toISOString(),
        version: '1.0.0',
        docs: '/api/v1/docs',
        endpoints: {
          baseApi: '/api/v1',
          swaggerDocs: '/api/v1/docs',
          superAdminWeb: 'http://192.168.29.44:3000',
          apkDownloads: '/apks',
          apkServer8080: 'http://192.168.29.44:8080',
        },
      });
    }
    next();
  });

  // Global API Prefix: /api/v1
  app.setGlobalPrefix('api/v1');

  // CORS configuration for frontends (Super Admin Web, Salesman Web, Android Flutter)
  app.enableCors({
    origin: '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    credentials: true,
  });

  // Global validation pipe
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: false,
    }),
  );

  // Global Exception filter and Transform interceptor
  app.useGlobalFilters(new AllExceptionsFilter());
  app.useGlobalInterceptors(new TransformInterceptor());

  // Swagger / OpenAPI documentation
  const config = new DocumentBuilder()
    .setTitle('Grand Aqua API')
    .setDescription(
      'Unified Backend REST API for Grand Aqua Super Admin Web/Android, Salesman Web/Android, and Buyer Android App',
    )
    .setVersion('1.0.0')
    .addBearerAuth()
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/v1/docs', app, document);

  const port = process.env.PORT || 4000;
  await app.listen(port, '0.0.0.0');
  console.log(`\n======================================================`);
  console.log(`🚀 Grand Aqua Unified Backend is running!`);
  console.log(`📡 Base API URL: http://localhost:${port}/api/v1`);
  console.log(`📚 Swagger Documentation: http://localhost:${port}/api/v1/docs`);
  console.log(`======================================================\n`);
}

bootstrap();
