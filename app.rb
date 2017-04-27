require 'rubygems'
require 'bundler'
require 'sinatra'
require 'httparty'
require 'json'
require 'chronic'
require 'dotenv'
require 'base64'

Bundler.require
Dotenv.load

config = {
  client_id:        ENV["CLIENT_ID"],
  client_secret:    ENV["CLIENT_SECRET"],
  slack_team_id:    ENV["SLACK_TEAM_ID"],
  slack_channel_id: ENV["SLACK_CHANNEL_ID"],
  outgoing_token:   ENV["OUTGOING_TOKEN"],
  timeframe: "2 weeks ago"
}

get '/' do
  'Welcome to SlackShopper! SlackShopper generates your shopping list from the Slack Shopping channel!'
end

post '/new-list' do
  if params[:token] == config[:outgoing_token]
    state = Base64.urlsafe_encode64('{"channel_id":"' + config[:slack_channel_id] + '", "timeframe":"' + params[:text] + '"}')
    headers = { 'Content-Type' => "application/json" }
    body = {  response_type: 'ephemeral',
              text: "Let's go shopping!",
              attachments: [
                {
                  color:  "00ACEF",
                  text:   "<https://slack.com/oauth/authorize?client_id=#{config[:client_id]}&state=#{state}&team=#{config[:slack_team_id]}&scope=channels:history|Click this link to generate your shopping list>"
                }
              ]
            }
    response = HTTParty.post(params[:response_url], body: body.to_json, headers: headers)
    puts "Request complete"
  end
end

get "/authorize" do
  state      = params[:state]
  code       = params[:code]
  auth_url   = "https://slack.com/api/oauth.access?client_id=#{config[:client_id]}&client_secret=#{config[:client_secret]}&code=#{code}"
  response   = JSON.parse(HTTParty.get(auth_url).body)
  auth_token = response["access_token"]
  redirect("/shopping-lists/new?token=#{auth_token}&state=#{state}")
end

get "/shopping-lists/new" do
  auth_token = params[:token]
  channel_id = config[:slack_channel_id]
  state = JSON.parse(Base64.urlsafe_decode64(params[:state]))
  @last_date = state["timeframe"]
  timeframe = Chronic.parse(state["timeframe"]).to_i
  @today = DateTime.now.strftime("%-m/%-d/%Y")
  hist_url = "https://slack.com/api/channels.history?token=#{auth_token}&channel=#{channel_id}&oldest=#{timeframe}"
  response = JSON.parse(HTTParty.get(hist_url).body)

  if response["messages"].nil?
    erb "no_items.html".to_sym
  else
    @shopping_list = response["messages"]
    @items = @shopping_list.map do |item|
      url = ""
      if item["text"].include? "<http"
        product = item["text"].split(" <").first
        url = "http" + item["text"].split("http")[1].split(">")[0]
      else
        product = item["text"]
        url = nil
      end
      [product, url]
    end
    erb "todays_list.html".to_sym
  end
end
