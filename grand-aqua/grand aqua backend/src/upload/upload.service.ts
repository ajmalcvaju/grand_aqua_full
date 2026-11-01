import { Injectable, BadRequestException } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class UploadService {
  private readonly uploadDir = path.join(process.cwd(), 'uploads');

  constructor() {
    if (!fs.existsSync(this.uploadDir)) {
      fs.mkdirSync(this.uploadDir, { recursive: true });
    }
  }

  formatFileResponse(file: Express.Multer.File, req: any) {
    if (!file) {
      throw new BadRequestException('No file uploaded or file format not supported');
    }

    const host = req.get('host') || '192.168.29.44:4000';
    const protocol = req.protocol || 'http';
    const relativePath = `/uploads/${file.filename}`;
    const fullUrl = `${protocol}://${host}${relativePath}`;

    return {
      filename: file.filename,
      originalName: file.originalname,
      mimetype: file.mimetype,
      size: file.size,
      relativePath,
      url: fullUrl,
    };
  }
}
