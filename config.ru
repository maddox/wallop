$LOAD_PATH.unshift File.expand_path("./app")
require 'boot'
require 'app'

run Sinatra::Application
