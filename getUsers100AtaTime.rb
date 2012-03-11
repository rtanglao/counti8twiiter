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

Twitter.configure do |config|
  config.consumer_key = consumer_key
  config.consumer_secret = consumer_secret
  config.oauth_token = access_token
  config.oauth_token_secret = access_token_secret
end

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

usersColl = db.collection("users")

number_blank_users_found = 0
id_str_array = []
usersColl.find().each do |u|
  if !u["user_info_initialized"]
    $stderr.printf("Pushing id:%s\n", u["id_str"])
    id_str_array.push(u["id_str"].to_i)
    number_blank_users_found += 1
  end
  if number_blank_users_found == 100
     number_blank_users_found = 0
     $stderr.printf("START of id_str_array\n")
       PP::pp(id_str_array, $stderr) 
     $stderr.printf("END of id_str_array: LENGTH:%d\n", id_str_array.length)
     one_hundred_users = Twitter.users(id_str_array)
     one_hundred_users.each do |full_user_info|
       $stderr.printf("START of user\n")
       PP::pp(full_user_info, $stderr) 
       $stderr.printf("END of user\n")
     end
     exit
  end
end


