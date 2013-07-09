EventMachine.run do
  module Wallop
    class App < Sinatra::Base
      register Sinatra::Reloader if RACK_ENV == 'development'
      enable :logging
      use Rack::CommonLogger, Wallop.logger

      configure do
        mime_type :m3u8, 'application/x-mpegURL'
        mime_type :ts, 'video/MP2T'
      end

      before do
        Wallop.request_host = request.host
        content_type :json
      end

      get '/' do
        redirect '/channels?type=favorites'
      end

      post '/channels/favorites' do
        Wallop.add_favorite_channel(params[:channel])
        JSON.dump({:status => 200, :message => 'ok'})
      end

      delete '/channels/favorites' do
        Wallop.remove_favorite_channel(params[:channel])
        JSON.dump({:status => 200, :message => 'ok'})
      end

      get '/channels' do
        case params[:type]
        when /hd/i
          @channels = Wallop.hd_lineup
        when /favorites/i
          @channels = Wallop.favorite_lineup
        else
          @channels = Wallop.lineup
        end

        content_type :html; halt erb :channels if request.accept.include?('text/html')
        JSON.dump({:channels => @channels})
      end

      post '/channels/:channel/tune' do
        resolution = params[:resolution] || '1280x720'
        bitrate = params[:bitrate] || '3000k'

        channel = params[:channel]

        if !Wallop.sessions.has_key?(channel)
          Wallop.cleanup_channel(channel)
          Wallop.logger.info "Tuning channel #{channel} with quality settings of #{resolution} @ #{bitrate}"
          pid  = POSIX::Spawn::spawn(Wallop.ffmpeg_command(channel, resolution, bitrate))
          Process::waitpid(pid, Process::WNOHANG)
          Wallop.logger.info "Creating session for channel #{channel}"
          Wallop.sessions[params[:channel]] = {:channel => channel, :pid => pid, :ready => false, :last_read => Time.now}
        end

        JSON.dump({:status => 200, :message => 'ok'})
      end

      get '/channels/:channel/status' do
        session = Wallop.sessions[params[:channel]]
        halt 404 if !session

        JSON.dump(session)
      end

      post '/channels/:channel/stop' do
        session = Wallop.sessions[params[:channel]]
        halt 404 if !session

        Wallop.logger.info "MANUALLY STOPPING SESSION - #{session[:channel]} - #{session[:pid]}"
        if Process.kill('QUIT', session[:pid])
          Process::waitpid(session[:pid])
          Wallop.cleanup_channel(session[:channel])
          Wallop.sessions.delete(session[:channel])
        end

        JSON.dump({:status => 200, :message => 'ok'})
      end

      get '/channels/:channel/raw' do
        redirect Wallop.raw_stream_url_for_channel(params[:channel])
      end


      get '/channels/:channel.m3u8' do
        content_type :m3u8

        session = Wallop.sessions[params[:channel]]
        halt 404 if !session

        halt 420 if !session[:ready]

        session[:last_read] = Time.now

        send_file(File.join(Wallop.transcoding_path, "#{session[:channel]}.m3u8"))
      end

      get %r{/(\d+.ts)} do
        content_type :ts
        send_file(File.join(Wallop.transcoding_path, params[:captures].first))
      end

      get '/channels/:channel' do
        content_type :html

        @channel = params[:channel]
        erb :channel
      end

    end
  end

  EventMachine.add_periodic_timer(0.5) { Wallop.sweep_sessions }
  Wallop::App.run!(:port=>Wallop.config['port'])
end
