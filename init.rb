Redmine::Plugin.register :note_change_notifier do
  name "Note Change Notifier plugin"
  author "Suren Grigoryan"
  description "Notify deal note change by e-mail"
  version "1.0.1"
  url "https://github.com/InstigateMobile/note_change_notifier"
  author_url "https://github.com/InstigateMobile/"
end

require "diff/lcs"
require "diff/lcs/hunk"

class NoteChangeMailer < Mailer
  class << self
    def deliver_note_edit(changer, note)
      if Redmine::VERSION::MAJOR >= 4
        deliver_note_edit_latest(changer, note)
      else
        deliver_note_edit_v3(changer, note)
      end
    end

    private
    def deliver_note_edit_latest(changer, note)
      @note = note
      users = (note.source.recipients + note.source.watcher_recipients).uniq
      users.each do |user|
        user_model = User.find_by_mail(user)
        mail = note_edit(changer, note, to: user_model)
        mail.deliver
      end
    end

    def deliver_note_edit_v3(changer, note)
      @note = note
      recipients = note.source.recipients
      to = recipients
      cc = (note.source.respond_to?(:all_watcher_recepients) ? note.source.all_watcher_recepients : note.source.watcher_recipients) - recipients
      mail = note_edit(changer,
                       note,
                       to & recipients,
                       cc & cc)
      mail.deliver
    end
  end

  def note_edit(changer, note, options)
    if options.key?(:cc)
      note_edit_v3(changer, note, options[:to], options[:cc])
    else
      note_edit_latest(changer, note, options[:to])
    end
  end

  private
  def note_edit_latest(changer, note, user)
    redmine_headers 'Project' => note.source.project.identifier,
                    'X-Notable-Id' => note.source.id,
                    'X-Note-Id' => note.id
    @author = note.author
    @changer = changer
    message_id note
    @users = (note.source.recipients + note.source.watcher_recipients).uniq

    message_id note
    references note
    @author = changer
    @changer = changer
    s = "[#{note.source.project.name} - #{note.source_type}  ##{note.source.id}] #{l(:label_crm_note_for)} #{note.source.name}"
    @note = note
    @user = user
    @users = [user]
    @note_url = url_for(:controller => 'notes',
                         :action => 'show',
                         :id => note,
                         :anchor => "change-#{note.id}")
    mail(:to => user.mail,
         :subject => s)
  end

  def note_edit_v3(changer, note, to_users, cc_users)
    redmine_headers 'Project' => note.source.project.identifier,
                    'X-Notable-Id' => note.source.id,
                    'X-Note-Id' => note.id
    @author = note.author
    @changer = changer
    message_id note
    recipients = note.source.recipients
    cc = (note.source.respond_to?(:all_watcher_recepients) ? note.source.all_watcher_recepients : note.source.watcher_recipients) - recipients
    @note = note
    #@note_details = note.visible_details(user)
    @note_url = url_for(:controller => 'notes', :action => 'show', :id => note.id)
    mail :to => recipients,
         :cc => cc,
         #:subject => "[#{note.source.project.name}] - #{l(:label_crm_note_for)} #{note.source.name}"
         :subject => "[#{note.source.project.name} - #{note.source_type}  ##{note.source.id}] #{l(:label_crm_note_for)} #{note.source.name}"
  end
end

class NoteChangeDiffer
  def initialize(note)
    @note = note
  end

  def diff
    if @note.previous_changes.key?("content")
      from, to, = @note.previous_changes["content"]
    else
      from = @note.content
      to = ""
    end
    unified_diff(from, to)
  end

  private
  def unified_diff(content_from, content_to)
    to_lines = content_to.lines.collect(&:chomp)
    from_lines = content_from.lines.collect(&:chomp)
    diffs = ::Diff::LCS.diff(from_lines, to_lines)

    unified_diff = ""

    old_hunk = nil
    n_lines = 3
    format = :unified
    file_length_difference = 0
    diffs.each do |piece|
      begin
        hunk = ::Diff::LCS::Hunk.new(from_lines, to_lines, piece, n_lines,
                                     file_length_difference)
        file_length_difference = hunk.file_length_difference

        next unless old_hunk

        if (n_lines > 0) and hunk.overlaps?(old_hunk)
          hunk.merge(old_hunk)
        else
          unified_diff << old_hunk.diff(format)
        end
      ensure
        old_hunk = hunk
        unified_diff << "\n"
      end
    end

    unified_diff << old_hunk.diff(format)
    unified_diff << "\n"
    unified_diff
  end
end

class NoteDiffNotifyListener < Redmine::Hook::Listener
  def plugin_redmine_contacts_controller_notes_edit_post(context)
    note = context[:note]
    #return unless note.previous_changes.key?("content")
    NoteChangeMailer.deliver_note_edit(User.current, note)
  end
end