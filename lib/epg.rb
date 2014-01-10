require 'zip/zip'
require 'json'
require 'date'

#
# Interface to a downloaded schedulesdirect.org Electronic Program Guide.
#
class EPG 
  class << self
    def open(file_name="sdjson.epg")
      epg = ::EPG.new(file_name)
      if block_given?
        begin
          yield epg
        ensure
          epg.close
        end
      else
        epg
      end
    end
  end
  
  def initialize(file="sdjson.epg")
    @zip = Zip::ZipFile.open(file)
  end
  
  def close()
    @zip.close()
  end
  
  def lineup_ids()
    JSON.parse(@zip.read('user.txt'))["headend"].map { |x| x["ID"] } 
  end

  def lineup(lineup_id=nil)
    lineup_id = self.lineup_ids()[0] if lineup_id.nil?
    JSON.parse(@zip.read("lineups/#{lineup_id}.txt"))
  end

  def channels(lineup_id=nil)
    lineup = self.lineup(lineup_id)
    
    stations = {}
    lineup["stations"].each do |station| 
      stations[station["stationID"]] = {:station_id=>station["stationID"], :name=>station["name"], :callsign=>station["callsign"]}
    end
    
    result = {}
    lineup[lineup["deviceTypes"][0]]["map"].each do |mapping|
      channel = mapping["channel"]
      result[channel] = stations[mapping["stationID"]]
    end
    
    result
  end

  def within?(at, start_time=nil, end_time=nil) 
    if start_time && end_time 
      start_time <= at && at < end_time
    else
      true
    end
  end
  
  def station_schedule(station_id, start_time=nil, end_time=nil) 
    program_cache = {}
    result = []
    JSON.parse(@zip.read("schedules/#{station_id}.txt")).map { |x|
      at = Time.at(DateTime.strptime(x["airDateTime"], '%Y-%m-%dT%T%Z').strftime('%s').to_i)
      if within?(at, start_time, end_time)
        result << self.program(x["programID"]).merge({ :at=>at , :duration=>x["duration"], :rating=>x["tvRating"], :first_run=>x["new"]})
      end
    }
    result
  end

  def longest_value(x) 
    if x 
      x.values.group_by(&:size).max.last.first
    else
      nil
    end
  end
  
  def program(program_id) 
    x = JSON.parse(@zip.read("programs/#{program_id}.txt"))
    ep_info = nil 
    if x["metadata"]
      metadata = x["metadata"][0]
      if metadata["tvdb"]
        si = metadata["tvdb"]
        ep_info = { :season=>si["season"], :episode=>si["episode"], :tvdb_id=>si["seriesid"] }
      elsif metadata["Tribune"]
        si = metadata["Tribune"]
        ep_info = { :season=>si["season"], :episode=>si["episode"], :tribune_id=>si["seriesid"] }
      elsif metadata["tvrage"]
        si = metadata["tvrage"]
        ep_info = { :season=>si["season"], :episode=>si["episode"], :tvrage=>true }
      elsif x["syndicatedEpisodeNumber"]
        ep_info = { :season=>"", :episode=>x["syndicatedEpisodeNumber"] }
      end
    end
    { :title=> longest_value(x["titles"]), :type=>x["showType"], :description=> longest_value(x["descriptions"]), :episode=>ep_info }
  end

  def upcoming_recodings(config, start_time=nil, end_time=nil)
    result = []
    schedules = {}
    
    channels = channels()

    # load up the schedules for the channels we have recordings interests in.
    priority = 1
    config.each do |interest| 
      channel = interest["channel"]
      if interest["show"] 
        show = interest["show"] 
        at = Time.at(show["at"])
        if within?(at, start_time, end_time)
          result << {:channel=> channel, :at=>at, :duration=>show["duration"], :file=>show["file"], :priority=>priority }
        end
        priority += 1 
      end
      if interest["series"] 
        series = interest["series"]
        schedules[channel] = self.station_schedule(channels[channel][:station_id], start_time, end_time) unless schedules[channel]
        schedule = schedules[channel]
        schedule.each do |program|
          if program[:title]==series["title"]
            if !series["first_run"] || program[:first_run]
              file = series["file"]
              file = file.gsub('${title}', program[:title].gsub(/[^a-zA-Z0-9_.,'-]+/, "-"))
              if program[:episode]
                file = file.gsub('${season}', "%02d" % program[:episode][:season])
                file = file.gsub('${episode}', "%02d" % program[:episode][:episode])
              else
                file = file.gsub('${season}', "")
                file = file.gsub('${episode}', "")
              end
              result << {:channel=> channel, :at=>program[:at], :duration=>program[:duration], :file=>file, :priority=>priority }
              priority += 1 
            end
          end
        end
      end
    end
    result
  end
  
end

# EPG.open do |epg|
#   puts epg.upcoming_recodings(JSON.parse(IO.read("config/recording.json")))
# end
