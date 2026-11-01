import { Module } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { NotificationsController } from './notifications.controller';
import { CommunicationsService } from './communications.service';

@Module({
  providers: [NotificationsService, CommunicationsService],
  controllers: [NotificationsController],
  exports: [NotificationsService, CommunicationsService],
})
export class NotificationsModule {}
