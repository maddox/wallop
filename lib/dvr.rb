include FileUtils
 
module DVR

  def self.logger 
    Wallop.logger
  end

  def self.config
    @config ||= TOML.load_file(File.join(RACK_ROOT, 'config', 'config.toml'))
  end

  def self.epg_path 
    config['schedulesdirect']['epg'] || File.join(Wallop.transcoding_path, "sdjson.epg")
  end

  def self.epg_path 
    config['schedulesdirect']['epg'] || File.join(Wallop.transcoding_path, "sdjson.epg")
  end

  def self.dead?(pid) 
    begin
      dead = Process::waitpid(pid, Process::WNOHANG)
    rescue Errno::ECHILD
      dead = true
    end
    dead
  end
  
  def self.update_epg
    if !@epg_update_pid
      java = config['schedulesdirect']['java'] || "java"
      username = config['schedulesdirect']['username']
      password = config['schedulesdirect']['password']
      sdjson = File.join(RACK_ROOT, "vendor", "sdjson.jar")
      logger.info "Updating Electronic Program Guide..."
      @epg_update_pid = POSIX::Spawn::spawn(%{exec #{java} -jar #{sdjson} --username #{username} --password #{password} grab --purge-cache --target '#{epg_path}' > log/sdjson.log})
    end
  end

  def self.refresh_upcoming_recodings
    config_file = config['recording'] || "config/recording.json"
    if !@epg_scanning && !@epg_update_pid && File.exist?(config_file) && config['schedulesdirect']
      @epg_scanning = true
      EM.defer do 
        logger.info "Scanning Electronic Program Guide for upcoming recodings."
        EPG.open(epg_path) do |epg|
          config_file_mtime = File.mtime(config_file)
          upcoming_recodings = epg.upcoming_recodings(JSON.parse(IO.read(config_file)))
          EM.next_tick do
            logger.info "Electronic Program Guide scan completed."
            now = Time.now
            @upcoming_recodings = upcoming_recodings.select { |x| now < x[:at]+x[:duration] }
            @config_file_mtime = config_file_mtime
            @epg_scanning = false
          end
        end
      end
    end
  end

  def self.within?(at, start_time, duration) 
    start_time < at && at < start_time+duration
  end

  def self.active_recodings
    @active_recodings ||= []
  end

  def self.recording_command(channel, duration, file)
    dir = File.dirname(file)
    mkdir_p(dir) unless File.directory?(dir)
    %{exec #{config['ffmpeg_path']} -i '#{Wallop.playlist_file_path(channel)}' -loglevel warning -threads 1 -t #{duration} -c copy '#{file}' > #{Wallop.channel_transcoding_path(channel)}/recording-ffmpeg.log 2>&1}
  end

  def self.record
    now = Time.now

    # Check to see if we need to update the epg
    if config['schedulesdirect']
      update = (config['schedulesdirect']['update'] || 60*60*24).to_i
      if !File.exist?(epg_path) || (File.mtime(epg_path)+update) < now
        update_epg
      end
      if @epg_update_pid && dead?(@epg_update_pid)
        @epg_update_pid = nil
        logger.info "Electronic Program Guide update completed."
        refresh_upcoming_recodings
      end
    end
    
    # Do we need to reload the upcoming_recodings?
    config_file = config['recording'] || "config/recording.json"
    if File.exist?(config_file) && ( File.mtime(config_file)!=@config_file_mtime || !@upcoming_recodings )
      refresh_upcoming_recodings
    end
    
    if @upcoming_recodings
      # get rid of recordings we are past.
      @upcoming_recodings = @upcoming_recodings.select { |x| now < x[:at]+x[:duration] }
      # logger.info "There are #{@upcoming_recodings.length} upcoming recordings." 

      # Now only figure out the active recordings and sorty by priority.
      @active_recodings =  @upcoming_recodings.select { |x| within?(now, x[:at], x[:duration]) }.sort_by{|x| x[:priority] }
      # logger.info "There are #{@active_recodings.length} active recordings." 
             
      @active_recodings.each do |recording|
        channel = recording[:channel]
        
        # Sanitize the channel id a bit.. perhaps we should make this configurable.. we are trying 
        # to make the EPG channel id match the channel id of the tunner.
        channel = channel.sub(/^[0:]*/,"").strip

        # Make sure we are tuned to the channel.
        if !Wallop.sessions.has_key?(channel)
          Wallop.tune(channel, '1280x720', '3000k')
        end
        
        # Mark the session active so that it stays tuned.
        session = Wallop.sessions[channel]
        session[:last_read] = Time.now
        
        # #TODO: Perhaps we need to stop the old recording..
        # old_recording = session[:recording]
        # if old_recording && old_recording!=recording
        # end
        
        duration = recording[:at] + (recording[:duration]+10) - now

        # Should we start the off the recording process...
        if session[:ready] && !session[:recording_pid] && !File.exist?(recording[:file]) && duration > 0
          session[:recording] = recording
          session[:recording_pid] = POSIX::Spawn::spawn(recording_command(channel, duration, recording[:file]))
        end
      end
      
      # Cleanup after completed recordings.
      Wallop.sessions.each do |channel, session|
        if session[:recording_pid] && dead?(session[:recording_pid])
          logger.info "RECORDING SESSSION COMPLETED - CLEANING UP - #{channel} - #{session[:recording_pid]}"
          session.delete(:recording_pid)
          session.delete(:recording)
        end
      end

    end
  end
end