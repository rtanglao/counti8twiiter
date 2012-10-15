#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'time'
require 'date'
require 'mongo'
require 'parseconfig'
require 'twitter'

if ARGV.length < 1
  puts "usage: #{$0} <twitter_screen_name>"
  exit
end

TWITTER_SCREEN_NAME = ARGV[0].downcase

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

tweetsColl = db.collection("tweets")
usersColl = db.collection("users")

tweet_ids_seen = []

u = usersColl.find_one({"screen_name" => TWITTER_SCREEN_NAME})
if u.nil?
  $stderr.printf "user:%s not_found\n",TWITTER_SCREEN_NAME
  exit
end

user_id = u["id"]

tweetsColl.find({"user.id" => user_id, "in_reply_to_screen_name"=> { "$ne" => nil}}).sort([["id", Mongo::DESCENDING]]).each do |t|
  tweet_id = t["id"]
  next if tweet_ids_seen.include?(tweet_id)
  $stderr.printf "found unique conversation id:%d text:%s\n", tweet_id, t["text"]
  in_reply_to_status_id = t["in_reply_to_status_id"]
  begin
    previous_tweet_in_convo = Twitter.status(in_reply_to_status_id)
  rescue Twitter::Error::NotFound
    $stderr.printf"**previous tweet not found\n"
    next
  end
  $stderr.printf "**PREVIOUS tweet id:%d text:%s\n", previous_tweet_in_convo["id"], previous_tweet_in_convo["text"]

  tweet_ids_seen.push(tweet_id)
end

# batch = 1
# num_tweets = 0
# lowest_tweet_id = 0
# previous_lowest_tweet_id = 0
# loop do 
#   $stderr.printf("LOWEST tweet id:%s, batch:%d\n",lowest_tweet_id.to_s, batch)
#   param_hash = {:count => 200, :trim_user => true, :include_rts => true,
#     :include_entities => true, :contributor_details => true}
#   if batch == 1
#     param_hash[:count] = 200
#   else
#     param_hash[:max_id] = lowest_tweet_id - 1
#   end
#   tried_previously = false  
#   begin 
#     Twitter.user_timeline(TWITTER_SCREEN_NAME, param_hash).each do |tweet|
#       t = tweet.attrs
#       id = t["id"]
#       if lowest_tweet_id == 0
#         lowest_tweet_id = id
#       elsif id < lowest_tweet_id
#         lowest_tweet_id = id
#       end
#       id_str = t["id_str"]
#       existingTweet =  tweetsColl.find_one("id_str" => id_str)
#       if existingTweet      
#         $stderr.printf("UPDATING tweet id:%s\n",id_str)
#         tweetsColl.update({"id_str" =>id_str}, t)
#       else
#         $stderr.printf("INSERTING tweet id:%s\n",id_str)
#         tweetsColl.insert(t)
#       end
#     end
#     if Twitter.rate_limit_status.remaining_hits == 1
#       $stderr.print("rate limited, sleeping for an hour\n")
#       sleep 60 * 60
#     end
#     num_tweets += 200
#     batch += 1
#     if num_tweets == 3200 || previous_lowest_tweet_id == lowest_tweet_id
#       break
#     else
#       previous_lowest_tweet_id = lowest_tweet_id
#     end
#     $stderr.printf("previous_lowest_tweet_id:%d, lowest_tweet_id:%d\n", 
#       previous_lowest_tweet_id, lowest_tweet_id)
#   rescue Twitter::Error::ServiceUnavailable, Twitter::Error::BadGateway
#     if tried_previously
#       raise
#     else
#       tried_previously = true
#       $stderr.printf("twitter ruby exception error, re-trying in 30 seconds\n")
#       sleep(30)
#       retry
#     end
#   end   
# end
# $stderr.printf("DONE!\n")



