import {
  Controller,
  Post,
  UseInterceptors,
  UploadedFile,
  UploadedFiles,
  Req,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor, FilesInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiConsumes, ApiBody } from '@nestjs/swagger';
import { diskStorage } from 'multer';
import * as path from 'path';
import * as fs from 'fs';
import { UploadService } from './upload.service';

const uploadStorage = diskStorage({
  destination: (req, file, cb) => {
    const uploadPath = path.join(process.cwd(), 'uploads');
    if (!fs.existsSync(uploadPath)) {
      fs.mkdirSync(uploadPath, { recursive: true });
    }
    cb(null, uploadPath);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const cleanName = path
      .basename(file.originalname, ext)
      .replace(/[^a-zA-Z0-9_-]/g, '_')
      .substring(0, 30);
    const uniqueSuffix = `${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    cb(null, `${cleanName || 'media'}_${uniqueSuffix}${ext}`);
  },
});

const fileFilter = (req: any, file: Express.Multer.File, cb: any) => {
  const allowedExtensions = [
    // Images
    '.jpg', '.jpeg', '.png', '.webp', '.svg', '.gif',
    // Videos
    '.mp4', '.webm', '.mov', '.m4v', '.mkv',
    // 3D Models
    '.glb', '.gltf', '.obj', '.stl', '.fbx',
  ];

  const ext = path.extname(file.originalname).toLowerCase();
  if (allowedExtensions.includes(ext)) {
    cb(null, true);
  } else {
    cb(
      new BadRequestException(
        `Unsupported file type "${ext}". Allowed: Images (${allowedExtensions.slice(0, 6).join(', ')}), Videos (${allowedExtensions.slice(6, 11).join(', ')}), 3D Models (${allowedExtensions.slice(11).join(', ')})`,
      ),
      false,
    );
  }
};

@ApiTags('File Uploads')
@Controller('upload')
export class UploadController {
  constructor(private uploadService: UploadService) {}

  @Post()
  @ApiOperation({ summary: 'Upload single product media file (Image, Video, or 3D Model)' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: {
          type: 'string',
          format: 'binary',
        },
      },
    },
  })
  @UseInterceptors(
    FileInterceptor('file', {
      storage: uploadStorage,
      limits: { fileSize: 100 * 1024 * 1024 }, // 100MB limit for 4K video / high-poly 3D models
      fileFilter,
    }),
  )
  uploadSingle(@UploadedFile() file: Express.Multer.File, @Req() req: any) {
    return this.uploadService.formatFileResponse(file, req);
  }

  @Post('multiple')
  @ApiOperation({ summary: 'Upload multiple product media files simultaneously' })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FilesInterceptor('files', 10, {
      storage: uploadStorage,
      limits: { fileSize: 100 * 1024 * 1024 },
      fileFilter,
    }),
  )
  uploadMultiple(@UploadedFiles() files: Express.Multer.File[], @Req() req: any) {
    if (!files || files.length === 0) {
      throw new BadRequestException('No files uploaded');
    }
    return files.map((f) => this.uploadService.formatFileResponse(f, req));
  }
}
