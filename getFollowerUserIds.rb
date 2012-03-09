#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'time'
require 'date'
require 'mongo'
require 'parseconfig'
require 'twitter'

twitter_config = ParseConfig.new('twitter.conf').params
consumer_key = twitter_config['consumer_key']
consumer_secret = twitter_config['consumer_secret']
access_token = twitter_config['access_token']
access_token_secret = twitter_config['access_token_secret']

if ARGV.length < 1
  puts "usage: #{$0} <twitter_screen_name>"
  exit
end

Twitter.configure do |config|
  config.consumer_key = consumer_key
  config.consumer_secret = consumer_secret
  config.oauth_token = access_token
  config.oauth_token_secret = access_token_secret
end

TWITTER_SCREEN_NAME = ARGV[0]

MONGO_HOST = ENV["MONGO_HOST"]
raise(StandardError,"Set Mongo hostname in ENV: 'MONGO_HOST'") if !MONGO_HOST
MONGO_PORT = ENV["MONGO_PORT"]
raise(StandardError,"Set Mongo port in ENV: 'MONGO_PORT'") if !MONGO_PORT
MONGO_USER = ENV["MONGO_USER"]
MONGO_PASSWORD = ENV["MONGO_PASSWORD"]
TWITTER_DB = ENV["TWITTER_DB"]
raise(StandardError,"Set Mongo flickr database name in ENV: 'TWITTER_DB'") if !TWITTER_DB

db = Mongo::Connection.new(MONGO_HOST, MONGO_PORT.to_i).db(TWITTER_DB)
if MONGO_USER
  auth = db.authenticate(MONGO_USER, MONGO_PASSWORD)
  if !auth
    raise(StandardError, "Couldn't authenticate, exiting")
    exit
  end
end

# user_info_initialized set to FALSE
# partial_following_screen_names=[]
# partial_following_screen_names.push[ids] iff. screen_names are not present in partial_following_screen_names
usersColl = db.collection("users")

cursor = "-1"
while cursor != 0 do
  followers = Twitter.follower_ids(TWITTER_SCREEN_NAME, :cursor => cursor, :stringify_ids => true)
  followers.ids.each do |id|
    pp id
  end
  cursor = followers.next_cursor
end

