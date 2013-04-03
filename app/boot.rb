require 'rubygems'
require 'fileutils'
require 'open-uri'
require 'logger'

require 'sinatra/base'
require 'sinatra/reloader'
require 'posix/spawn'
require 'eventmachine'
require 'thin'
require 'json'
require 'toml'

RACK_ROOT = File.dirname(File.expand_path(__FILE__)) + '/../'
RACK_ENV = ENV['RACK_ENV'] || 'development'

$LOAD_PATH.unshift File.expand_path("#{RACK_ROOT}/lib")

require 'extensions'
require 'wallop'

Wallop.setup
