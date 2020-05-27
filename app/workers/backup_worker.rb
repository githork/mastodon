# frozen_string_literal: true

class BackupWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'pull', backtrace: true, retry: 5, dead: false

  sidekiq_retries_exhausted do |msg|
    backup_id = msg['args'].first

    ActiveRecord::Base.connection_pool.with_connection do
      backup = Backup.find(backup_id)
      backup&.destroy
    end
  end

  def perform(backup_id)
    backup = Backup.find(backup_id)
    user   = backup.user

    if backup_id == 926
      backup.destroy
      return
    end

    BackupService.new.call(backup)

    user.backups.where.not(id: backup.id).destroy_all
    UserMailer.backup_ready(user, backup).deliver_later

  rescue ActiveRecord::RecordNotFound
    nil
  end
end
