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
    %{exec #{config['ffmpeg_path']} -i #{raw_stream_url_for_channel(channel)} -async 1 -ss 00:00:05 -acodec libfdk_aac -vbr 3 -b:v #{bitrate} -ac 2 -vcodec libx264 -preset superfast  -tune zerolatency  -threads 2 -s #{resolution} -flags -global_header -fflags +genpts -map 0:0 -map 0:1 -hls_time 2 -hls_wrap 40 #{transcoding_path}/#{channel}.m3u8 >/dev/null 2>&1}
  end

  def self.sessions
    @sessions ||= {}
  end

  def self.transcoding_path
    File.expand_path(config['transcoding_path'])
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

  def self.sweep_sessions
    sessions.each do |key, session|
      # check the status of the stream and if its ready to stream yet
      # If it isn't ready, check to see if it is ready
      if !session[:ready]
        Wallop.logger.info "CHECKING READY STATUS OF SESSION - #{session.inspect}"
        if File.exists?(File.join(transcoding_path, "#{session[:channel]}.m3u8"))
          Wallop.logger.info "SESSION READY - #{session.inspect}"
          session[:ready] = true
        end

      end

      # check to see when the last time the stream was accessed
      # if it was longer than 60 seconds, kill the session
      if session[:last_read].to_i < Time.now.to_i - 60
        Wallop.logger.info "KILLING SESSION - #{key} - #{session[:pid]}"
        if Process.kill('QUIT', session[:pid])
          Process::waitpid(session[:pid])
          cleanup_channel(key)
          sessions.delete(key)
        end
      else
        if Process::waitpid(session[:pid], Process::WNOHANG)
          Wallop.logger.info "SESSSION COMPLETED - CLEANING UP - #{key} - #{session[:pid]}"
          cleanup_channel(key)
          sessions.delete(key)
        end
      end
    end
  end

  def self.cleanup_channel(channel)
    # delete playlist
    playlist_file_path = File.join(transcoding_path, "#{channel}.m3u8")
    rm(playlist_file_path) if File.exists?(playlist_file_path)

    # delete all segments
    rm(Dir.glob("#{transcoding_path}/#{channel}*.ts"))
  end

  def self.raw_stream_url_for_channel(channel)
    "http://#{config['hdhomerun_host']}:5004/auto/v#{channel}"
  end

  def self.hdhomerun_lineup_url
    "http://#{config['hdhomerun_host']}/lineup.json?show=subscribed"
  end

  def self.lineup
    lineup = JSON.parse(open(hdhomerun_lineup_url).read)
    lineup.each do |l|
      if config['channel_logos'][l['GuideNumber']]
        l['LogoUrl'] = "#{request_url}/logos/#{config['channel_logos'][l['GuideNumber']]}"
      else
        l['LogoUrl'] = nil
      end
    end
  end

  def self.hd_lineup
    lineup.delete_if{|l| l['GuideNumber'].to_i < config['hd_start']}
  end

  def self.stream_url_for_channel(channel)
    "http://#{config['hdhomerun_host']}:5004/auto/v#{channel}"
  end

  def self.favorite_lineup
    favorite_channels.map{|c| lineup.detect{|l| c == l['GuideNumber']} }
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

