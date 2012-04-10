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

TWITTER_SCREEN_NAME = ARGV[0].downcase

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

def getFollowersOf(follower_id, synthetic_followers_of_followers, usersColl)
  new_followers_of_follower = []
  followers_of_follower_cursor = "-1"
  while followers_of_follower_cursor != 0 do
    followers_of_follower = Twitter.follower_ids(:user_id => follower_id, :cursor => followers_of_follower_cursor)
    followers_of_follower.ids.each do |id|
      if synthetic_followers_of_followers.include?(id)
        next
      end
      $stderr.printf("NEW follower of follower:%d IS:%d\n", follower_id, id)
      new_followers_of_follower.push(id)
      existingFollowerOfFollowerUser =  usersColl.find_one("id_str" => id.to_s)
      if !existingFollowerOfFollowerUser      
        $stderr.printf("INSERTING FOLLOWER of FOLLOWER user id:%s\n", id.to_s)
        followerOfFollowerUser = { "id_str" => id.to_s, "user_info_initialized" => false,  "partial_following_screen_names" => []}
        usersColl.insert(followerOfFollowerUser)
      end
    end
  end
  return new_followers_of_follower
end

def getFollowsOfFollowersOfFollowers(new_synthetic_followers_of_followers,
      synthetic_follows_of_followers_of_followers, usersColl)
  new_follows_of_followers_of_followers = []
  new_synthetic_followers_of_followers.each do |id|
    follows_of_follower_of_follower_cursor = "-1"
    follows_of_follower_of_follower = Twitter.friends_ids(:user_id => id, :cursor => follows_of_follower_of_follower_cursor)
    follows_of_follower_of_follower.ids.each do |follow_id| 
      if synthetic_follows_of_followers_of_followers.include?(follow_id)
        next
      end
      $stderr.printf("NEW follow of follower of follower:%d IS:%d\n", id, follow_id)
      new_follows_of_followers_of_followers.push(follow_id)
      existingFollowOfFollowerOfFollowerUser =  usersColl.find_one("id_str" => follow_id.to_s)
      if !existingFollowFollowerOfFollowerUser      
        $stderr.printf("INSERTING FOLLOW of FOLLOWER of FOLLOWER user id:%s\n", follow_id.to_s)
        followOfFollowerOfFollowerUser = { "id_str" => follow_id.to_s, "user_info_initialized" => false,  
          "partial_following_screen_names" => []}
        usersColl.insert(followOfFollowerOfFollowerUser)
      end
    end
  end
  return new_follows_of_followers_of_follower
end

usersColl = db.collection("users")

existingUser =  usersColl.find_one("screen_name" => TWITTER_SCREEN_NAME)
if !existingUser
  $stderr.printf("screen_name:%s NOT FOUND\n", TWITTER_SCREEN_NAME)
  exit
end

synthetic_followers_of_followers = []
synthetic_followers = []
synthetic_follows_of_followers_of_followers = []

follower_cursor = "-1"
while follower_cursor != 0 do
  followers = Twitter.follower_ids(TWITTER_SCREEN_NAME, :cursor => follower_cursor)
  followers.ids.each do |id|
    $stderr.printf("FOUND follower user id:%s\n", id.to_s)
    if !synthetic_followers.include?(id)
      synthetic_followers.push(id)
    end
    existingFollowerUser =  usersColl.find_one("id_str" => id.to_s)
    if existingFollowerUser      
      if !existingFollowerUser["partial_following_screen_names"].include?(TWITTER_SCREEN_NAME)
        existingFollowerUser["partial_following_screen_names"].push(TWITTER_SCREEN_NAME)
        $stderr.printf("UPDATING user id:%s ADDING screen_name:%s\n",id.to_s, TWITTER_SCREEN_NAME )
        usersColl.update({"id_str" =>id.to_s}, existingFollowerUser)
      else
        $stderr.printf("NOT UPDATING Follower user id:%s because screen_name:%s is PRESENT\n",id.to_s, TWITTER_SCREEN_NAME )
      end
    else
      $stderr.printf("INSERTING user id:%s\n",id.to_s)
      followerUser = { "id_str" => id.to_s, "user_info_initialized" => false,  "partial_following_screen_names" => [TWITTER_SCREEN_NAME]}
      usersColl.insert(followerUser)
    end
    new_synthetic_followers_of_followers = getFollowersOf(id, synthetic_followers_of_followers, usersColl)
    synthetic_followers_of_followers.concat(new_synthetic_followers_of_followers)
    new_synthetic_follows_of_followers_of_followers = getFollowsOfFollowersOfFollowers(new_synthetic_followers_of_followers,
      synthetic_follows_of_followers_of_followers, usersColl)
    follows_of_followers_of_followers.concat(new_synthetic_follows_of_followers_of_followers)
  end
  follower_cursor = followers.next_cursor
end

existingUser["synthetic_followers_of_followers"] = synthetic_followers_of_followers
existingUser["synthetic_followers"] = synthetic_followers
existingUser["synthetic_follows_of_followers_of_followers"] = synthetic_follows_of_followers_of_followers 

existingUser.update({"id_str" => existingUser["id_str"]}, existingUser)

