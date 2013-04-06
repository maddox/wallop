def plist_path
  File.expand_path("~/Library/LaunchAgents/com.wallop.plist")
end

def log_path
  File.expand_path("~/Library/Logs/wallop.log")
end

namespace :wallop do

  desc "Uninstall Wallop from launching on boot"
  task :uninstall do
    puts "Removing Wallop from launchd"

    if File.exist?(plist_path)
      `launchctl unload -w #{plist_path}`
    end

  end

  desc "Install Wallop to launch on boot"
  task :install do
    puts "Setting up Wallop in launchd"

    plist = %{
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
        <dict>
          <key>EnvironmentVariables</key>
          <dict>
            <key>RACK_ENV</key>
            <string>production</string>
          </dict>
          <key>Label</key>
          <string>com.wallop.plist</string>
          <key>ProgramArguments</key>
          <array>
            <string>script/start</string>
          </array>
          <key>OnDemand</key>
          <false/>
          <key>AbandonProcessGroup</key>
          <false/>
          <key>RunAtLoad</key>
          <true/>
          <key>KeepAlive</key>
          <true/>
          <key>WorkingDirectory</key>
          <string>#{File.join(File.dirname(__FILE__))}</string>
          <key>StandardErrorPath</key>
          <string>#{log_path}</string>
          <key>StandardOutPath</key>
          <string>#{log_path}</string>
        </dict>
      </plist>
    }

    `touch #{log_path}`

    File.open(plist_path, 'w+') do |f|
      f.puts plist
    end

    `launchctl load -w #{plist_path}`
  end

end
