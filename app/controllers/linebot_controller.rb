class LinebotController < ApplicationController
  require 'line/bot'  # gem "line-bot-api"
  require 'net/https'
  require 'uri'
  require 'cgi'
  require 'json'
  require 'securerandom'
  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery except: [:callback]

  def client
    @client ||= Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token = ENV['LINE_CHANNEL_TOKEN']
    end
  end

  def callback
    body = request.body.read

    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end

    endpoint = "https://api.cognitive.microsofttranslator.com/"
    path = '/translate?api-version=3.0'
    params = '&to=en'
    
    # response = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
    #     http.request (request)
    # end

    events = client.parse_events_from(body)
    events.each { |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          json = translate_uri event.message['text']
          results = JSON.parse(json)
          p results[0]["translations"][0]
          puts "test"
          results.each do |result|
            puts result["translations"]
            puts result.class
          end
          puts"testo"
          message = {
              type: 'text',
              text: results[0]
          }
          client.reply_message(event['replyToken'], message)
        end
      end
    }

    head :ok
  end

  private
  def translate_uri translated
    uri = URI.parse("https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&to=en")
    # http =  Net::HTTP.new(uri.host, uri.port)
    # http.use_ssl = uri.scheme === "https"
    content = '[{"Text" : "' + translated + '"}]'
    request = Net::HTTP::Post.new(uri)
    request['Content-type'] = 'application/json'
    request['Content-length'] = content.length
    request['Ocp-Apim-Subscription-Key'] = "12b164cec1be4fb0a61683ac16e71223"
    request['X-ClientTraceId'] = SecureRandom.uuid
    request.body = content
    
    response = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        http.request (request)
    end
    result = response.body.force_encoding("utf-8")
    json = JSON.pretty_generate(JSON.parse(result))
    return json
  end
end