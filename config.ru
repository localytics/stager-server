require 'rubygems'
require 'bundler'

Bundler.require

require './env.rb' if File.exist? './env.rb'
require './stager.rb'

run Stager
