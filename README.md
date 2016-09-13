# :zap: Wallop :zap:

Wallop is a transcoding server for your [HDHomeRun Prime](https://www.silicondust.com/product/hdhomerun-prime/).

Wallop lets you watch TV streams on your iPhone, iPad, Roku, Web, Android device. Even away from home.

## Warning

Wallop is still very new, and because of that, it's unstable.

Not unstable as in crash prone, unstable as in lots will change. Not a lot has been decided on, so things could change any time. Keep an eye on the [pull requests](https://github.com/maddox/wallop/pulls) in this repo to see what is new and what has changed.

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

```
$ brew update
$ cp vendor/libaacplus.rb /usr/local/Library/Formula/
$ cp vendor/x264.rb /usr/local/Library/Formula/
$ brew install x264 --HEAD
$ brew install vendor/ffmpeg.rb --with-fdk-aac --with-libaacplus --with-libvo-aacenc --with-schroedinger --with-opencore-amr --disable-stripping
```

### Quickie Set Up

Wallop is a simple Ruby server. All you need to do is clone it down, install its dependencies, and start it up!

Be sure you have bundler installed first. `gem install bundler` Bundler is a dependency management tool for Ruby.

```sh
git clone https://github.com/maddox/wallop.git
cd wallop
script/setup
script/start
open http://127.0.0.1:8888
```

### Starting Server

To start the server after you've already set it up, just run this:

```sh
script/start
open http://127.0.0.1:8888
```

### Installing/Uninstalling

You can optionally use [launchd](http://en.wikipedia.org/wiki/Launchd) in OS X to start Wallop on boot. Not only will this start the server when the computer boots, but it will keep it running in case it crashes.

I'd suggest you make sure Wallop is running normally via `script/start` before you install it this way.

#### Install

This will install the script to launch it at boot and keep it alive. If you seem to be having trouble, you can tail the log for the install at `~/Library/Logs/wallop.log`.

```sh
script/install
```

#### Uninstall

This will remove the script from launchd.

```sh
script/uninstall
```

#### Restart

This will restart the server. If you update the server, you'll want to run this to get the updates running.

```sh
script/restart
```
### Updating

If you want to update Wallop, just do a normal `git pull` on the repo you cloned down. Watch the development via this repo to see if there's anything you want to update for.

After updating the code, run:

```sh
script/update
```

This will fulfill any new dependencies as well as anything else that needs to happen after an update.

### Configuring

Wallop is pretty simple, but it does have a couple user configurable settings.

You can edit these settings via the `config/config.toml.example` file. Once you have updated your setting save the file back to the config directory as `config.toml`.

```toml
hdhomerun_host = "192.168.1.13"
ffmpeg_path = "/usr/local/bin/ffmpeg"
transcoding_path = "./tmp"
port = "8888"
hd_start = 500
```

##### `hdhomerun_host`
The IP address of your HDHomeRun Prime on your network.

##### `ffmpeg_path`
The path to your FFMPEG binary.

##### `transcoding_path`
The path where Wallop will write the temporary segments when transcoding and streaming the tv streams. This defaults to the `tmp` directory in Wallops own directory. If you want these files written somewhere else, you can change that here.

##### `port`
The port that the server will run on.

##### `hd_start`
The start channel of your HD channels. Most providers start all of their HD channels at a certain number. Providing this number will let you browse JUST your HD channels.

### Network Logos

Wallop supports the serving of Network Logos if you configure your channels to use them. Within the `config.toml` file, you can map your channels to images. Just map the channel number to a file name and place those files into `/app/public/logos`. Wallop will send the logo urls along in its JSON response to services talking to it.

```
[channel_logos]
506 = "cbs.png"
508 = "abc.png"
511 = "fox.png"
512 = "nbc.png"
```

you can see that `cbs.png` corresponds to:

![](/app/public/logos/cbs.png)

## Logs

Logs are written out to the `log` directory.

Wallop rolls its logs whenever it starts up. So only information for the current process will be found in `log/wallop.log`. When Wallop starts, it moves the old log to `log/wallop.old.log` before starting up.

## Usage

Wallop is more of a tool than a user facing application. It's designed to be used in coordination with other things like:

* an iPhone app
* an XBMC/Plex addon/channel

It has a full API that lets you kick off the transcode, pick your resolution and bitrate, and provides status of the stream. [Read the documentation](/docs) on how to talk to Wallop.

### Via Web

Wallop DOES have some web views that you can use to watch a stream though. Just open the server with your browser to see a list of channels. Tap/click a channel to start the stream.

Just point your browser to [http://localhost:8888](http://localhost:8888), or whatever host it's on.

Just tap/click a channel, and it will do it's thing and start streaming.

![](http://cl.ly/image/1j1s3J2q0r16/Image%202013.04.09%2012:35:42%20PM.png)

### Favorite Channels

You have LOTS of channels. To alleviate this pain, you can set which ones are your favorites. Just tap/click the star and it will be set as a favorite channel.

This should speed up getting to the channels you want.

### Browser Support

Basically the only browser that is supported right now is Safari. Sorry, Google hates HLS for some reason.

Chrome won't play the HLS stream natively, and [JWPlayer](http://www.longtailvideo.com/jw-player/pricing/) wants $300 per year for their player that will fallback to flash for HLS streams. Even for non-commercial use. :thumbsdown:

* :thumbsup: iPhone (Safari)
* :thumbsup: iPad (Safari)
* :thumbsup: OS X (Safari)
* :thumbsdown: Chrome
* :question: Android

I don't have any Android devices, nor do I have any experience with them. So your milage may vary. I'd love to hear some feedback via [issues](https://github.com/maddox/wallop/issues)

## Docker Image

To get Wallop up and running quickly you can use the Docker image provided by
[ipstatic](https://github.com/ipstatic). It contains everything required to run
Wallop.

On a machine that has Docker installed, pull the image down:

```sh
docker pull ipstatic/wallop
```

Next copy the sample config.toml file and ensure these directives are set:
```toml
ffmpeg_path = "/ffmpeg/bin/ffmpeg"
acodec = "libfdk_aac"
transcoding_path = "/tmp"
```

Then start the container:

```sh
docker run --rm --name wallop -v $(pwd)/config.toml:/wallop/config/config.toml -p 8888:8888 ipstatic/wallop:latest
```

## Contributing

* Fork the repo
* Create a topic branch
* Push your topic branch
* Submit a pull request for your feature
