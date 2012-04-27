#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'time'
require 'date'
require 'mongo'
require 'parseconfig'
require 'uri'
require 'net/http'

def lengthen(url)
  uri = URI(url)
  Net::HTTP.new(uri.host, uri.port).get(uri.path).header['location']
end

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

num_customer_feedback_url_mentions = 0
tweetsColl = db.collection("tweets")

# 61617150 is the user id for translink
tweetsColl.find({"user.id" => 61617150}, :fields => ["id", "entities"]).each do |t|
  id = t["id"]
  t["entities"]["urls"].each do |u|
    url = u["expanded_url"]
    $stderr.printf("expanded_url:%s\n", url)
    if url.start_with?("http://ht.")
      expanded_url = lengthen(url)
    else
      expanded_url = url
    end
    $stderr.printf("tweet id:%d mentions url:%s, display url:%s, expanded url:%s\n", id, u["url"], u["display_url"], expanded_url)    
    if expanded_url.include?("cCustomerComplaint")
      $stderr.printf("tweet:%d has cCustomerComplaint in url\n", id)
      num_customer_feedback_url_mentions += 1
    end
  end
end

printf("num_customer_feedback_url_mentions:%d\n", num_customer_feedback_url_mentions)


