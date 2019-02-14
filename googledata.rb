class Googledata

  attr_accessor :type, :scope, :api, :api_version, :max_results, :page_list, :next_page, :parameters, :current_page

  def initialize (type)
    #sets default values based on the type of pull
    self.type = type
    self.next_page = nil
    self.current_page = nil
    self.max_results = '30'
    self.page_list = []
    case type
      when "file"
        self.api = "drive"
        self.api_version = 'v2'
        self.scope = 'https://www.googleapis.com/auth/drive'
      when "email"
        self.api = "gmail"
        self.api_version = 'v1'
        self.scope = 'https://mail.google.com/'
      when "calendar"
        self.api = "calendar"
        self.api_version = 'v3'
        self.scope = 'https://www.googleapis.com/auth/calendar'
      when "contact"
        self.api = "contacts"
        self.api_version = 'v3'
        self.scope = "https://www.google.com/m8/feeds"
    end
  end

  def parameters
    parameters = {}
    if defined?(self.max_results) && !self.max_results.nil?
      parameters.merge!('maxResults' => self.max_results)
    end
    if defined?(self.next_page) && self.next_page != nil
      parameters.merge!('pageToken' => self.next_page)
    end
    case self.type
      when "file"
        #no special params
      when "email"
        parameters.merge!('userId' => 'me', 'q' => '!in:chat')
      when "calendar"
        parameters.merge!('calendarId' => 'primary', 'singleEvents' => 'true', 'orderBy' => 'startTime', 'timeMin' => Time.now.to_datetime.rfc3339)
      when "contact"
        #no special params
    end
    parameters
  end

  def pull(token)
    api_client = Google::APIClient.new(application_name: 'Mashboard', application_version: '0.0.1')
    api_client.authorization.client_id = Mashboard::Application.config.google_id
    api_client.authorization.client_secret = Mashboard::Application.config.google_secret
    api_client.authorization.scope = self.scope
    auth = api_client.authorization.dup
    auth.update_token!(access_token: token)
    discovered_api ||= api_client.discovered_api(self.api, self.api_version)
    case self.api
      when "drive"
        pull = api_client.execute(:api_method => discovered_api.files.list, :parameters => self.parameters, :authorization => auth)
        result = pull.data['items']
        self.current_page = self.next_page
        self.next_page = pull.data['nextPageToken']
        self.page_list << pull.data['nextPageToken']
      when "calendar"
        pull = api_client.execute(:api_method => discovered_api.events.list, :parameters => self.parameters, :authorization => auth)
        self.current_page = self.next_page
        self.next_page = pull.data['nextPageToken']
        self.page_list << pull.data['nextPageToken']
        items = pull.data['items']
        result = []
        items.each do |item|
          result << {:title => item.summary, :creator => item.creator['displayName'], :date => item.start['dateTime'], :link => item.htmlLink}
        end
      when "gmail"
        email_list = api_client.execute(:api_method => discovered_api.users.messages.list, :parameters => self.parameters, :authorization => auth)
        self.current_page = self.next_page
        self.next_page = email_list.data['nextPageToken']
        self.page_list << email_list.data['nextPageToken']
        email_body = JSON.parse email_list.body
        result = []

        # Use the Google Batch interface to grab email details.
        batch = Google::APIClient::BatchRequest.new

        email_body['messages'].each do |email|
          batch.add(:api_method => discovered_api.users.messages.get,
                    :parameters => {'userId' => 'me', 'id' => email['id'], 'format' => 'metadata'}
          )
        end
        batch_result = api_client.execute(batch, :authorization => auth).to_json
        msgBatch = JSON.parse(batch_result)
        msgBatch_body = msgBatch["response"]["body"]
        entries = msgBatch_body.strip.split(/^--.*/)
        entries.shift
        messages = entries.map { |entry| JSON.parse entry[/{.*/m] }

        p "===============messages: #{messages}==============="

        messages.each do |response|
          id = response['id']
          headers = response['payload']['headers']

          p "==========headers: #{headers}=============}}}}}"

          subject = headers.select { |header| header["name"] == "Subject" }
          if subject.any?
            subject = subject[0]['value']
          else
            subject = ""
          end
          if subject.length > 0
            from_name = headers.select { |header| header["name"] == "From" }[0]['value']
            if from_name.length > 0
              from_split = from_name.split("<")
              from_name = from_split[0]
              from_email = from_split[1];
            end
            puts "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% #{DateTime.parse(headers.select { |header| header["name"] == "Date" }[0]['value'])}"
            rec_date = DateTime.parse(headers.select { |header| header["name"] == "Date" }[0]['value'])
            if response.has_key?("labelIds")
              unread = response['labelIds'].include?("UNREAD")
            else
              unread = FALSE
            end

            if response['payload']['mimeType'] == "multipart/mixed"
              attachment = TRUE
            else
              attachment = FALSE
            end

            result << {:id => id, :sender => from_name, :sender_email => from_email, :subject => subject, :timestamp => rec_date, :unread => unread, :attachment => attachment}
          end
        end

      when "contact"
        #result = @api_client.execute(:api_method => @discovered_api.files.list, :authorization => auth)
        oauth_client = OAuth2::Client.new(Mashboard::Application.config.google_id, Mashboard::Application.config.google_secret, :site => 'https://accounts.google.com/o/oauth2/auth')
        #oauth = OAuth2::AccessToken.from_hash(oauth_client, source.oauth_token)
        #google_contacts_user = GoogleContactsApi::User.new(oauth)
        result = oauth_client
      else
    end
    result
  end

  def files_search(token, searchText)
    api_client = Google::APIClient.new(application_name: 'Mashboard', application_version: '0.0.1')
    api_client.authorization.client_id = Mashboard::Application.config.google_id
    api_client.authorization.client_secret = Mashboard::Application.config.google_secret
    api_client.authorization.scope = self.scope
    auth = api_client.authorization.dup
    auth.update_token!(access_token: token)
    discovered_api ||= api_client.discovered_api(self.api, self.api_version)

    searchParamters = {'q' => "fullText contains '#{searchText}'"}

    pull = api_client.execute(:api_method => discovered_api.files.list, :parameters => searchParamters, :authorization => auth)
    result = pull.data['items']
    result
  end

  def calendar_search(token, searchText)
    api_client = Google::APIClient.new(application_name: 'Mashboard', application_version: '0.0.1')
    api_client.authorization.client_id = Mashboard::Application.config.google_id
    api_client.authorization.client_secret = Mashboard::Application.config.google_secret
    api_client.authorization.scope = self.scope
    auth = api_client.authorization.dup
    auth.update_token!(access_token: token)
    discovered_api ||= api_client.discovered_api(self.api, self.api_version)

    searchParamters = {'calendarId' => 'primary', 'singleEvents' => 'true', 'orderBy' => 'startTime', 'timeMin' => Time.now.to_datetime.rfc3339, 'q' => "fullText contains '#{searchText}'"}

    pull = api_client.execute(:api_method => discovered_api.events.list, :parameters => searchParamters, :authorization => auth)
    items = pull.data['items']
    result = []
    items.each do |item|
      result << {:title => item.summary, :creator => item.creator['displayName'], :date => item.start['dateTime'], :link => item.htmlLink}
    end
    puts result
    result
  end

  def email_search(token, searchText)
    api_client = Google::APIClient.new(application_name: 'Mashboard', application_version: '0.0.1')
    api_client.authorization.client_id = Mashboard::Application.config.google_id
    api_client.authorization.client_secret = Mashboard::Application.config.google_secret
    api_client.authorization.scope = self.scope
    auth = api_client.authorization.dup
    auth.update_token!(access_token: token)
    discovered_api ||= api_client.discovered_api(self.api, self.api_version)

    searchParamters = {'userId' => 'me', 'q' => "!in:chat #{searchText}"}

    email_list = api_client.execute(:api_method => discovered_api.users.messages.list, :parameters => searchParamters, :authorization => auth)
    email_body = JSON.parse email_list.body
    result = []
    email_body['messages'].each do |email|
      message_raw = api_client.execute(:api_method => discovered_api.users.messages.get, :parameters => {'userId' => 'me', 'id' => email['id']}, :authorization => auth)
      message = JSON.parse message_raw.body
      headers = message['payload']['headers']
      subject = headers.select { |header| header["name"] == "Subject" }[0]['value']
      if subject.length > 0
        from_name = headers.select { |header| header["name"] == "From" }[0]['value']
        if from_name.length > 0
          from_split = from_name.split("<")
          from_name = from_split[0]
        end
        rec_date = DateTime.parse(headers.select { |header| header["name"] == "Date" }[0]['value']).to_s(:short)
        unread = message['labelIds'].include?("UNREAD")
        if message['payload']['mimeType'] == "multipart/mixed"
          attachment = TRUE
        else
          attachment = FALSE
        end
        id = message['id']
        result << {:id => id, :sender => from_name, :subject => subject, :timestamp => rec_date, :unread => unread, :attachment => attachment}
      end
    end
    result
  end

  #old gmail implementation with IMAP
  def gmail_pull(user)
    #depricated but kept for IMAP reference
    imap = Net::IMAP.new('imap.gmail.com', 993, usessl = true, certs = nil, verify = false)
    imap.authenticate('XOAUTH2', user.email, user.oauth_token)
    imap.examine('Inbox')
    @items = Array.new
    #set for only today right now
    @time = "#{Date.today.day}-#{I18n.t("date.abbr_month_names")[Date.today.month]}-#{Date.today.year}"
    imap.search(["SINCE", @time]).each do |mid|
      @items.push imap.fetch(mid, "ENVELOPE")[0].attr["ENVELOPE"]
    end
    #imap.logout
    imap.disconnect
    @items
  end
end