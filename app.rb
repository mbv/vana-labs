require 'sinatra'
require 'mongo'
require 'slim'
require 'nokogiri'
require 'tzinfo'

configure do
  db = Mongo::Client.new(['mongodb:27017'], database: 'vana-labs')
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
  tz = TZInfo::Timezone.get('Europe/Minsk')
  @labs = settings.mongo_db.find.to_a.sort_by { |lab| lab[:date] }.map do |lab|
    lab[:date] = tz.utc_to_local(lab[:date]).strftime("%d.%m.%Y %H:%M:%S")
    lab[:processed] = tz.utc_to_local(lab[:processed]).strftime("%d.%m.%Y %H:%M:%S")
    lab[:git_results] = lab[:git_results].map do |git_result|
      git_result[:time] = tz.utc_to_local(Time.at(git_result[:time])).strftime("%d.%m.%Y %H:%M:%S") if git_result[:time]
      git_result
    end
    lab
  end

  erb :index
end