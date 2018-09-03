# frozen_string_literal: true

require 'net/imap'
require 'mail'
require 'json'
require 'rugged'
require 'securerandom'
require 'nokogiri'
require 'mongo'

class EmailChecker
  def initialize(mongo_publisher)
    @mongo_publisher = mongo_publisher
  end

  def start_check
    config = YAML.safe_load(File.read('../config/mail_receiver.yml'))
                 .each_with_object({}) { |(k, v), memo| memo[k.to_sym] = v; }

    sleep_time = config.delete(:sleep_time)

    loop do
      begin
        imap = Net::IMAP.new(config[:host], config[:port], true)
        imap.login(config[:username], config[:password])

        imap.select('Inbox')

        imap.uid_search(%w[NOT DELETED]).each do |uid|
          source = imap.uid_fetch(uid, ['RFC822']).first.attr['RFC822']

          result = EmailMessage.receive(source)
          @mongo_publisher.save(result[:body]) if result[:status] == :ok

          imap.uid_store(uid, '+FLAGS', [:Deleted])
        end

        imap.expunge
        imap.logout
        imap.disconnect
      rescue Net::IMAP::NoResponseError => e
        puts "No Response Error: #{e}"
      rescue Net::IMAP::ByeResponseError => e
        puts "Bye Response Error: #{e}"
      rescue StandardError => e
        puts "Fatal Error: #{e}"
      end

      sleep(sleep_time)
    end
  end
end

class EmailMessage
  def self.receive(source)
    regexp_subject   = /\[СПП\]\s*:\s+([а-яА-ЯёЁ0-9. ]+)\s*-\s*ЛР\s*(\d+)/m
    regexp_git_links = /((https?|git@)(:\/\/)?([\w_@:-]+(?:(?:\.[\w_-]+)+))([\w.,@?^=%&:\/~+#-]*[\w@?^=%&\/~+#-])?)/i


    message = Mail.read_from_string source
    if (matches = regexp_subject.match(message.subject))
      full_name  = matches[1]
      lab_number = matches[2]

      git_links = []

      parts = []
      if message.body.parts.count.positive?
        parts = message.body.parts.map(&:decoded)
      else
        parts << message.body.decoded
      end

      parts.each do |part|
        Nokogiri::HTML(part).text.scan(regexp_git_links) do |match|
          git_links << match[0]
        end
      end

      git_links.uniq!

      git_results = git_links.map do |link|
        GitCheck.new.check(link)
      end

      return {
          status: :ok,
          body:   {
              full_name:     full_name,
              lab_number:    lab_number,
              message_parts: parts,
              git_results:   git_results,
              processed:     Time.now,
              date:          message.date

          }
      }

    end

    {
        status: :error
    }
  end
end

class GitCheck
  def check(url)
    name = SecureRandom.hex(10)
    Dir.mkdir('/tmp/checkout') unless File.exist?(File.join('/tmp', 'checkout'))
    begin
      repo = Rugged::Repository.clone_at(url, File.join('/tmp', 'checkout', name), depth: 1)
    rescue Rugged::NetworkError => e
      puts e
      return {
          status: :error_clone,
          url:    url
      }
    rescue Rugged::SshError => e
      puts e
      return {
          status: :not_access,
          url:    url
      }
    end


    unless repo.branches.exist? 'master'
      return {
          status: :not_master_branch,
          url:    url
      }
    end


    {
        status:  :ok,
        url:     url,
        hash:    repo.branches['master'].target_id,
        time:    repo.branches['master'].target.time,
        message: repo.branches['master'].target.message
    }
  end
end

class MongoPublisher
  def initialize
    @client = Mongo::Client.new(['mongodb:27017'], database: 'vana-labs')
  end

  def save(message)
    collection = @client[:labs]

    collection.insert_one(message)
  end

end

EmailChecker.new(MongoPublisher.new).start_check
