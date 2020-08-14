# Journal Change Notifier

Journal Change Notifier is a Redmine plugin that notifies journal
change by e-mail.

## License

GPL 2 or later. See LICENSE for details.

# Note Change Notifier

Note Change Notifier is a Redmine plugin that notifies note
change of contact/deal in redmine_contacts' plugin by e-mail. Note Change Notifier
is based on (modified) Journal Change Notifier. Plugin tested on redmine 
version 3.4.2.

# Installation of note_change_notifier plugin

1. Install plugin as usual:
<pre>
$ sudo cp -r note_change_notifier [Redmine_Root]/plugins
$ cd [Redmine_Root]
$ sudo bundle install
$ sudo bundle exec rake redmine:plugins:migrate RAILS_ENV=production
$ sudo /etc/init.d/apache2 restart
</pre>
2. Edit [Redmine_Root]/plugins/redmine_contacts/app/controllers/notes_controller.rb (add call_hook to update and destroy methods), as follows:
<pre>
...
...
...
  def update
    @note.safe_attributes = params[:note]
    if @note.save
      @note.note_time = params[:note][:note_time] if params[:note] && params[:note][:note_time]
      attachments = Attachment.attach_files(@note, (params[:attachments] || (params[:note] && params[:note][:uploads])))  
      render_attachment_warning_if_needed(@note)
      flash[:notice] = l(:notice_successful_update)
      respond_to do |format|
        format.html { redirect_back_or_default({ :action => 'show', :project_id => @note.source.project, :id => @note }) }
        format.api  { render_api_ok }
      end 
+     call_hook(:plugin_redmine_contacts_controller_notes_edit_post, { :note => @note, :params => params}) if Redmine::Plugin.installed?(:note_change_notifier)
    else
      respond_to do |format|
        format.html { render :action => 'edit', :project_id => params[:project_id], :id => @note }
        format.api  { render_validation_errors(@note) }
      end
    end
  end
...
...
...
  def destroy
    (render_403; return false) unless @note.destroyable_by?(User.current, @project)
    @note.destroy
    respond_to do |format|
      format.js
      format.html { redirect_to :action => 'show', :project_id => @project, :id => @note.source }
      format.api  { render_api_ok }
    end
+   call_hook(:plugin_redmine_contacts_controller_notes_edit_post, { :note => @note, :params => params}) if Redmine::Plugin.installed?(:note_change_notifier)
    # redirect_to :action => 'show', :project_id => @project, :id => @contact
  end
...
...
...
</pre>

# Plugin's issue in internal redmine

https://intranet.instigatemobile.com/issues/12990
