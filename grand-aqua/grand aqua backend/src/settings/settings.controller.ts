import { Controller, Get, Put, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { SettingsService } from './settings.service';
import { UserRoleType } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { AuthGuard } from '@nestjs/passport';

@ApiTags('Settings & Admin Roles')
@Controller('settings')
@UseGuards(AuthGuard('jwt'), RolesGuard)
@ApiBearerAuth()
export class SettingsController {
  constructor(private settingsService: SettingsService) {}

  @Get()
  @ApiOperation({ summary: 'Get global company and platform settings' })
  async getSettings() {
    return this.settingsService.getAllSettings();
  }

  @Put()
  @Roles(UserRoleType.SUPER_ADMIN)
  @ApiOperation({ summary: 'Update company setting (Super Admin only)' })
  async updateSetting(@Body() body: { key: string; value: string; description?: string }) {
    return this.settingsService.updateSetting(body.key, body.value, body.description);
  }

  @Get('admin-staff')
  @Roles(UserRoleType.SUPER_ADMIN)
  @ApiOperation({ summary: 'List all administrative staff and roles' })
  async getAdminStaff() {
    return this.settingsService.getAdminStaff();
  }

  @Get('roles')
  @Roles(UserRoleType.SUPER_ADMIN)
  @ApiOperation({ summary: 'List RBAC roles and permissions' })
  async getRoles() {
    return this.settingsService.getRoles();
  }
}
