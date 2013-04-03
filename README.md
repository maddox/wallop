# :zap: Wallop :zap:

Wallop is a transcoding server for your HDHomeRun Prime.

Wallop lets you watch TV streams on your iPhone, iPad, Roku, Web, Android device. Even away from home.

## Why?

The HDHomeRun Prime is an amazing CableCard TV tuner. It has 3 tuners, and makes its tuned content available over your local network. It even lets you capture these streams via HTTP with a simple CURL command!

The problem is, TV is generally broadcast in MPEG2 at bitrates hovering around 16-20mbps. This causes 3 problems:

* These streams are usually too large for WiFi.
* These streams are definitely too large to stream to your mobile device when away from home.
* Basically no modern devices decode MPEG2 in hardware, leaving the devices to do it with CPU.

This means, as awesome as this device is, and as accessible as the TV streams are, it's still basically useless. It can't stream to your phone, tablet, or even over your WiFi.

The solution is simple. Take these MPEG2 streams and transcode them to h.264 at a lower bitrate. That's what Wallop does.

## How

Using FFMPEG, Wallop tunes the channel you request and consumes the stream from the HDHomeRun. It then transcodes it to a more consumable bitrate and broadcasts it as an HTTP Live Stream.

Voila! Now basically any modern device can stream TV from your HDHomeRun Prime.


## Setup

Wallop is written in Ruby and runs fine with the Ruby that ships on OS X 10.8.

Wallop has only been tested running on OS X, though its just Ruby and FFMPEG, so it should run ok elsewhere.

### FFMPEG

You should have a modern version of FFMPEG compiled and installed. I'd suggest you just compile a fresh version from the most recent source. [Here](http://ffmpeg.org/trac/ffmpeg/wiki/MacOSXCompilationGuide) are good instructions on how get FFMPEG built for OS X. It's not that bad!

### Installing and Starting

Wallop is a simple Ruby server. All you need to do is clone it down, install its dependencies, and start it up!

Be sure you have bundler installed first. `gem install bundler` Bundler is a dependency management tool for Ruby.

```sh
git clone https://github.com/maddox/wallop.git
cd wallop
script/setup
script/server
open http://127.0.0.1:8888
```

### Configuring

Wallop is pretty simple, but it does have a couple user configurable settings.

You can edit these settings via the `config/config.toml` file.

```toml
HDHOMERUN_HOST = "192.168.1.13"
FFMPEG_PATH = "/usr/local/bin/ffmpeg"
TRANSCODING_PATH = "./tmp"
PORT = "8888"
```

##### `HDHOMERUN_HOST`
The IP address of your HDHomeRun Prime on your network.

##### `FFMPEG_PATH`
The path to your FFMPEG binary.

##### `TRANSCODING_PATH`
The path where Wallop will write the temporary segments when transcoding and streaming the tv streams. This defaults to the `tmp` directory in Wallops own directory. If you want these files written somewhere else, you can change that here.

##### `PORT`
The port that the server will run on.

### Logs

Logs are written out to the `log` directory.

Wallop rolls its logs whenever it starts up. So only information for the current process will be found in `log/wallop.log`. When Wallop starts, it moves the old log to `log/wallop.old.log` before starting up.

## Usage

Wallop is more of a tool than a user facing application. It's designed to be used in coordination with other things like:

* an iPhone app
* an XBMC/Plex addon/channel

It has a full API that lets you kick off the transcode, pick your resolution and bitrate, and provides status of the stream. [Read the documentation](/docs) on how to talk to Wallop.

Wallop DOES have some web views that you can use to start a stream though. Just open the server with your browser to see a list of channels. Clicking one will start the transcode and when it's ready, it'll redirect you to the stream.


## Contributing

* Fork the repo
* Create a topic branch
* Push your topic branch
* Submit a pull request for your feature
