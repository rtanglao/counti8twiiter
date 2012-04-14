#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'time'
require 'date'
require 'mongo'
require 'parseconfig'
require 'net/http'
require 'open-uri'
require 'builder'

class Grapher
  
  attr_reader :data, :xml, :db, :usersColl

  def initialize
    @data = {:nodes => [], :edges => []}
    @xml = Builder::XmlMarkup.new(:ident => 1)
    
    @db = Mongo::Connection.new(MONGO_HOST, MONGO_PORT.to_i).db(TWITTER_DB)
    if MONGO_USER
      auth = @db.authenticate(MONGO_USER, MONGO_PASSWORD)
      if !auth
        raise(StandardError, "Couldn't authenticate, exiting")
        exit
      end
    end
    @usersColl = db.collection("users")
  end

  def parse_followers_of_translink_greenestcity()
    add_node("translink")
    add_node("greenestcity")
    @usersColl.find({"partial_following_screen_names" =>  { "$all" => ["translink", "greenestcity"]}}, 
                    :fields => ["screen_name"]).each do |user|
      screen_name = user["screen_name"].downcase
      $stderr.printf("screen_name:%s\n", screen_name)
      add_node(screen_name)
      $stderr.printf("ADDED NODE for screen_name:%s\n", screen_name)
      add_edge(screen_name, "translink")
      $stderr.printf("ADDED EDGE for screen_name:%s to translink edge\n", screen_name)
      add_edge(screen_name, "greenestcity")
      $stderr.printf("ADDED EDGE for screen_name:%s to greenestcity edge\n", screen_name)
    end
  end

  def generate_gexf
    @xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
    @xml.gexf(:xmlns => "http://www.gexf.net/1.2draft", :version => "1.2") do
      @xml.meta(:lastmodifieddate => Time.now.strftime("%Y-%m-%d")) do
        @xml.creator "Tetalab"
        @xml.description "translinkAndGreenestcityFollowers"
      end
      @xml.graph(:mode => "static", :defaultedgetype => "directed") do
        @xml.nodes(:count => @data[:nodes].size) do
          @data[:nodes].each do |node|
            @xml.node :id => node[:id], :label => node[:label]
            if node[:parents]
              @xml.parents do
                node[:parents].each do |parent|
                  @xml.parent :for => parent
                end
              end
            end
          end
        end
        @xml.edges(:count => @data[:edges].size) do
          @data[:edges].each do |edge|
            @xml.edge :id => edge[:id], :source => edge[:source], :target => edge[:target], :weight => edge[:weight]
          end
        end
      end
    end
    return @xml.target!
  end

  private

  def add_node(node)
    @data[:nodes] << {:id => node, :label => node} if data[:nodes].select{|node| node[:id] == node}.empty?
  end
  
  def add_edge(node1, node2)
    if edge = @data[:edges].select{|edge| edge[:id] == "#{node1}-#{node2}"}.pop
      edge[:weight] += 1
    else
      @data[:edges] << {:id => "#{node1}-#{node2}", :source => node1, :target => node2, :weight => 1}
    end
  end
end

MONGO_HOST = ENV["MONGO_HOST"]
raise(StandardError,"Set Mongo hostname in ENV: 'MONGO_HOST'") if !MONGO_HOST
MONGO_PORT = ENV["MONGO_PORT"]
raise(StandardError,"Set Mongo port in ENV: 'MONGO_PORT'") if !MONGO_PORT
MONGO_USER = ENV["MONGO_USER"]
MONGO_PASSWORD = ENV["MONGO_PASSWORD"]
TWITTER_DB = ENV["TWITTER_DB"]
raise(StandardError,"Set Mongo flickr database name in ENV: 'TWITTER_DB'") if !TWITTER_DB

graph = Grapher.new
graph.parse_followers_of_translink_greenestcity()
#p graph.data

File.open('followersOfTranslinkAndGreenestCity.gexf', "w") do |f|
  f.write graph.generate_gexf
end
