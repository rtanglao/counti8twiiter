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
raise(StandardError,"Set Mongo twitter database name in ENV: 'TWITTER_DB'") if !TWITTER_DB

db = Mongo::Connection.new(MONGO_HOST, MONGO_PORT.to_i).db(TWITTER_DB)
if MONGO_USER
  auth = db.authenticate(MONGO_USER, MONGO_PASSWORD)
  if !auth
    raise(StandardError, "Couldn't authenticate, exiting")
    exit
  end
end


def get100orLessUsers(id_str_array, usersColl)
  users = Twitter.users(id_str_array)
  users.each do |full_user_info|
    full_user_info_hash = {}
    full_user_info.instance_variables.each {|var| full_user_info_hash[var.to_s.delete("@")] = full_user_info.instance_variable_get(var) }
    full_user_info_hash = full_user_info_hash.merge(full_user_info_hash).delete("attrs")

    full_user_info_hash["user_info_initialized"] = true
    id_str = full_user_info_hash["id_str"]
    mongo_user = usersColl.find_one("id_str" => id_str)
    if mongo_user
      full_user_info_hash["partial_following_screen_names"] = mongo_user["partial_following_screen_names"]
      usersColl.update({"id_str" => id_str}, full_user_info_hash)
    else
      usersColl.insert({"id_str" => id_str}, full_user_info_hash)
    end
  end
end

usersColl = db.collection("users")

number_blank_users_found = 0
id_str_array = []
usersColl.find().each do |u|
  if !u["user_info_initialized"]
    id_str_array.push(u["id_str"].to_i)
    number_blank_users_found += 1
  end
  if number_blank_users_found == 100
    get100orLessUsers(id_str_array, usersColl)
    number_blank_users_found = 0
    id_str_array = []
  end
end
if number_blank_users_found != 0
  get100orLessUsers(id_str_array, usersColl)
end


