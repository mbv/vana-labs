# frozen_string_literal: true

require 'net/imap'
require 'mail'
require 'json'
require 'git'
require 'securerandom'

class EmailChecker
  def start_check
    config = YAML.safe_load(File.read('mail_receiver.yml'))
                 .each_with_object({}) { |(k, v), memo| memo[k.to_sym] = v; }

    sleep_time = config.delete(:sleep_time)

    loop do
      begin
        imap = Net::IMAP.new(config[:host], config[:port], true)
        imap.login(config[:username], config[:password])

        imap.select('Inbox')


        imap.uid_search(%w[NOT DELETED]).each do |uid|

          source = imap.uid_fetch(uid, ['RFC822']).first.attr['RFC822']


          EmailMessage.receive(source)


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
    regexp_subject = /\[СПП\]\s*:\s+([а-яА-ЯёЁ0-9 ]+)\s*-\s*ЛР\s*(\d+)/m
    regexp_git_links = /((?:git|ssh|https?|git@[-\w.]+):(\/\/)?(.*?)(\.git)(\/?|\#[-\d\w._]+?))/m

    message = Mail.read_from_string source
    if matches = regexp_subject.match(message.subject)
      full_name = matches[1]
      lab_number = matches[2]


      git_links = []
      message.body.decoded.scan(regexp_git_links) do |match|
        git_links << match[0]
      end

      git_links.uniq!

      git_links.each do |link|
        GitCheck.new.check(link)
      end

      print({
                full_name: full_name,
                lab_number: lab_number,
                message: message.body.decoded,
                git_links: git_links
            })

    end

    #print(message)
  end
end

class GitCheck
  def check(url)
    name = SecureRandom.hex(10)
    g = Git.clone(url, name, :path => '/tmp/checkout')
    print g.log
    print "\n"
    print g.branches[:master].gcommit
    print "\n"
    commit = g.branches[:master].gcommit
    {
        name: commit.name,
        date: commit.date,
        hash: commit.sha,
        message: commit.message
    }
  end
end

EmailChecker.new.start_check
