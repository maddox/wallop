include FileUtils

module Wallop
  LOG_PATH = 'log/wallop.log'
  OLD_LOG_PATH = 'log/wallop.old.log'
  FAVORITE_CHANNELS_PATH = 'config/favorite_channels.json'

  def self.request_host
    @request_host
  end

  def self.request_host=(host)
    @request_host = host
  end

  def self.request_url
    "http://#{request_host}:8888"
  end

  def self.logger
    @logger ||= Logger.new(LOG_PATH)
  end

  def self.config
    @config ||= TOML.load_file(File.join(RACK_ROOT, 'config', 'config.toml'))
  end

  def self.ffmpeg_command(channel, resolution='1280x720', bitrate='3000k')
    %{exec #{config['ffmpeg_path']} -threads 4 -f mpegts -analyzeduration 2000000 -i #{raw_stream_url_for_channel(channel)} -bufsize 100Mi -loglevel warning -async 1 -ac 2 -acodec libfdk_aac -b:v #{bitrate} -minrate #{bitrate.gsub(/\d+/){ |o| (o.to_i * 0.80).to_i }} -maxrate #{bitrate} -vcodec libx264 -preset superfast -tune zerolatency -s #{resolution} -flags -global_header -fflags +genpts -map 0:0 -map 0:1 -hls_time 2 -hls_wrap 40 #{playlist_file_path(channel)} > #{channel_transcoding_path(channel)}/live-ffmpeg.log 2>&1}
  end

  def self.snapshot_command(channel, width=nil)
    width ||= 'iw/3'
    file = "#{channel}-#{Time.now.to_i}.png"
    [%{#{config['ffmpeg_path']} -r 1 -f mpegts -analyzeduration 2000000 -i #{raw_stream_url_for_channel(channel)} -vcodec png -map 0:0 -an -sn -updatefirst 1 -t 00:00:01 -vf scale=#{width}:-1 app/public/snapshots/#{file} -loglevel quiet}, file]
  end

  def self.snapshot(channel, width=nil)
    cmd, file = snapshot_command(channel, width)
    EM.system(cmd){ yield file }
  end

  def self.sessions
    @sessions ||= {}
  end

  def self.transcoding_path
    File.expand_path(config['transcoding_path'])
  end

  def self.channel_transcoding_path(channel)
    File.join(transcoding_path, "channel-#{channel}")
  end

  def self.playlist_file_path(channel)
    File.join(self.channel_transcoding_path(channel), "live.m3u8")
  end

  def self.setup
    # create log and transcoding directories
    ["log", transcoding_path].each do |dir|
      mkdir_p(dir) unless File.directory?(dir)
    end

    # roll the logs
    mv(LOG_PATH, OLD_LOG_PATH) if File.exists?(LOG_PATH)
    Wallop.logger.info "Starting up"
  end
  
  def self.tune(channel, resolution, bitrate)
    cleanup_channel(channel)
    logger.info "Tuning channel #{channel} with quality settings of #{resolution} @ #{bitrate}"
    mkdir_p(channel_transcoding_path(channel)) unless File.directory?(channel_transcoding_path(channel))
    pid  = POSIX::Spawn::spawn(Wallop.ffmpeg_command(channel, resolution, bitrate))
    Process::waitpid(pid, Process::WNOHANG)
    logger.info "Creating session for channel #{channel}"
    sessions[channel] = {:channel => channel, :pid => pid, :ready => false, :last_read => Time.now}
  end
  
  def self.sweep_sessions
    sessions.each do |key, session|
      # check the status of the stream and if its ready to stream yet
      # If it isn't ready, check to see if it is ready
      if !session[:ready]
        Wallop.logger.info "CHECKING READY STATUS OF SESSION - #{session.inspect}"
        if File.exists?(self.playlist_file_path(session[:channel]))
          Wallop.logger.info "SESSION READY - #{session.inspect}"
          session[:ready] = true
        end

      end

      # check to see when the last time the stream was accessed
      # if it was longer than 60 seconds, kill the session
      if session[:last_read].to_i < Time.now.to_i - 60
        Wallop.logger.info "KILLING SESSION - #{key} - #{session[:pid]}"
        if Process.kill('QUIT', session[:pid])
          begin
            Process::waitpid(session[:pid])
          rescue Errno::ECHILD
          end
          cleanup_channel(key)
        end
      else
        begin
          dead = Process::waitpid(session[:pid], Process::WNOHANG)
        rescue Errno::ECHILD
          dead = true
        end
        if dead
          Wallop.logger.info "SESSSION COMPLETED - CLEANING UP - #{key} - #{session[:pid]}"
          cleanup_channel(key)
        end
      end
    end
  end

  def self.cleanup_channel(channel)
    sessions.delete(channel)

    # delete playlist
    file = self.playlist_file_path(channel)
    rm(file) if File.exists?(file)

    # delete all segments
    rm(Dir.glob("#{channel_transcoding_path(channel)}/live*.ts"))
  rescue Errno::ENOENT
  end

  def self.raw_stream_url_for_channel(channel)
    "http://#{config['hdhomerun_host']}:5004/auto/v#{channel}"
  end

  def self.hdhomerun_lineup_url
    "http://#{config['hdhomerun_host']}/lineup.json?show=subscribed"
  end

  def self.lineup
    lineup = @lineup ||= JSON.parse(open(hdhomerun_lineup_url).read)
    lineup.each do |l|
      l['Favorite'] = false
      if config['channel_logos'][l['GuideNumber']]
        l['LogoUrl'] = "#{request_url}/logos/#{config['channel_logos'][l['GuideNumber']]}"
      else
        l['LogoUrl'] = nil
      end
      if favorite_channels.include?(l['GuideNumber'])
        l['Favorite'] = true
      end
      if l['GuideNumber'].to_i >= config['hd_start']
        l['HD'] = true
      end
    end
  end

  def self.favorite_lineup
    lineup.select{|l| l['Favorite'] }
  end

  def self.hd_lineup
    lineup.select{|l| l['HD'] }
  end

  def self.stream_url_for_channel(channel)
    "http://#{config['hdhomerun_host']}:5004/auto/v#{channel}"
  end

  def self.favorite_channels
    @favorite_channels ||= begin
      if File.exists?(FAVORITE_CHANNELS_PATH)
        JSON.parse(open(FAVORITE_CHANNELS_PATH).read)
      else
        []
      end
    end
  end

  def self.add_favorite_channel(channel)
    favorite_channels << channel unless favorite_channels.include?(channel)
    favorite_channels.sort!
    save_favorite_channels
  end

  def self.remove_favorite_channel(channel)
    favorite_channels.delete(channel)
    save_favorite_channels
  end

  def self.save_favorite_channels
    open(FAVORITE_CHANNELS_PATH, 'w+') do |f|
      f.write JSON.dump(favorite_channels)
    end
  end

end
