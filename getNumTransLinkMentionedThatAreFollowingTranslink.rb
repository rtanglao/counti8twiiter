#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'time'
require 'date'
require 'mongo'
require 'parseconfig'

TWITTER_SCREEN_NAME = "translink"

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

num_mentioned_by_translink_that_are_following_translink = 0
usersColl = db.collection("users")
tweetsColl = db.collection("tweets")

# 61617150 is the user id for translink
tweetsColl.find({"user.id" => 61617150}, :fields => ["id", "entities"]).each do |t|
  t["entities"]["user_mentions"].each do |u|
    $stderr.printf("tweet id:%d has mention by id:%d, name:%s\n", t["id"], u["id"], u["name"])
    id_of_user_mentioned = u["id"]
    user = usersColl.find_one({"id" => id_of_user_mentioned}, :fields => ["partial_following_screen_names"])
    if !user
      next
    end
    if user["partial_following_screen_names"].include?("translink")
      $stderr.printf("user id:%d is following translink and was mentioned by translink\n", id_of_user_mentioned)
      num_mentioned_by_translink_that_are_following_translink += 1
    end
  end
end

printf("num_mentioned_by_translink_that_are_following_translink:%d\n", num_mentioned_by_translink_that_are_following_translink)


