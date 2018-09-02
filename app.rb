require 'sinatra'
require 'mongo'
require 'slim'
require 'nokogiri'
require 'tzinfo'

configure do
  db = Mongo::Client.new(['127.0.0.1:27017'], database: 'vana-labs')
  set :mongo_db, db[:labs]
end


helpers do
  def message(message)
    doc = Nokogiri.HTML(message)

    doc.css('script').remove

    doc.xpath("//@*[starts-with(name(),'on')]").remove
    doc
  end
end


get '/' do
  @labs = settings.mongo_db.find.to_a.sort_by { |lab| lab[:date] }

  slim :index
end