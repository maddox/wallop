$LOAD_PATH.unshift File.join(File.dirname(__FILE__))
require 'boot'

case (ARGV.shift || "help")
when "update"
  DVR.update_epg
  
when "recordings"
  EPG.open(DVR.epg_path) do |epg|
    upcoming_recodings = epg.upcoming_recodings(JSON.parse(IO.read(DVR.config_file)))
    now = Time.now
    upcoming_recodings = upcoming_recodings.select { |x| now < x[:at]+x[:duration] }
    upcoming_recodings = upcoming_recodings.sort_by { |x| x[:at] }
    puts "      Date/Time      | Channel | Show"
    upcoming_recodings.each do |x|
      puts ("#{x[:at].strftime('%D %R')}-#{(x[:at]+x[:duration]).strftime('%R')} | %7s | %s " % [x[:channel], x[:title]])
    end
  end

when "search"
  
  EPG.open(DVR.epg_path) do |epg|
    epg.show_search(ARGV.join(" ")).each do |show, channels|
      puts "Found: '#{show}', on channels: #{channels.join(", ")}"
    end
  end  
  
else
   
  puts "commands:"
  puts "  help        Show this screen."
  puts "  update      Updates the EPG data."
  puts "  recordings   Show upcomming recordings."
  puts "  search      Search for show names to find the channels they are aired on"
  puts ""

end


