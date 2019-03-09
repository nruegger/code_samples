module Sources
  module GoogleApi
    class Contact < Sources::Google
      API ||= 'contacts'
      API_VERSION ||= 'v3'
      SCOPE ||= 'https://www.googleapis.com/auth/contacts.readonly'

      def search
        options[:cache_key] ||= items_cache_with_filter
        options[:search_text] ||= filters_keys.join('|')
        keyword_search(call)
      end

      def call
        process_request do
          client = OAuth2::Client.new(auth.client_id, auth.client_secret, site: 'https://www.google.com/accounts/AuthSubSessionToken')
          token = OAuth2::AccessToken.new(client, source.oauth_token_decrypted)
          google_contacts_user = GoogleContactsApi::User.new(token)
          begin
            google_contacts_user.contacts.map { |c| parse_contact(c) }
          rescue GoogleContactsApi::UnauthorizedError
            notifications = []
            notifications.push Notifications::Base.create("source_#{source.id}", :main, I18n.t('sources.google.errors.auth_main', email: source.email))
            notifications.push Notifications::Base.create("source_#{source.id}", :widget, I18n.t('sources.google.errors.auth_widget', email: source.email))
            {notifications: notifications}
          rescue
            notifications = []
            notifications.push Notifications::Base.create("source_#{source.id}", :widget, I18n.t('sources.google.errors.unknown', email: source.email))
            {notifications: notifications}
          end
        end
      end

      def process_request
        cache_items = keyword_search(Rails.cache.read(options[:cache_key])) || []
        # max_items = (options[:page].to_i * options[:per_page].to_i) - 1
        # puts "cache data returned for #{source.email}" if cache_items.present?
        return cache_items if cache_items.present?

        result = yield
        return result if result.is_a?(Hash)

        items = (result + cache_items).uniq.sort_by { |r| r[:sort].to_s }
        # puts "writing cache for #{source.email}"
        Rails.cache.write(options[:cache_key], items, expires_in: 5.minutes)
        items
      end

      def keyword_search(items)
        return if items.blank?
        return items if options[:search_text].blank?
        regex_search = Regexp.new(options[:search_text], Regexp::IGNORECASE)
        items.select do |hash|
          !!hash.values_at(:first, :last, :primary_email).detect { |value| value =~ regex_search }
        end
      end

      def parse_contact(contact)
        display_name = contact.family_name + ', ' + contact.given_name if contact.given_name && contact.family_name
        photo_link = "#{contact.photo_link}&access_token=#{source.oauth_token_decrypted}" if contact.photo_link_entry['gd$etag']

        sort = sort_key(display_name || contact.family_name || contact.given_name || contact.primary_email || contact.title)
        
        link = 'https://contacts.google.com/?authuser='+source.email+'#contact/'+contact.id.split('/').last
        {
            id: contact.id.split('/').last,
            name: display_name || contact.full_name.presence || contact.title.presence || contact.company || contact.primary_email || contact.given_name || 'n/a',
            first: contact.given_name,
            last: contact.family_name,
            primary_email: contact.primary_email,
            emails: contact.emails,
            link: link,
            photo_link: photo_link || '',
            organizations: contact.organizations,
            addresses: contact.addresses,
            phone: contact.phone_numbers,
            sort: sort || '',
            source_label: source.email
        }
      end

      def sort_key(key)
        first_letter = key[0, 1]
        (key.downcase if letter?(first_letter)) || ('zzzzzz' + key.downcase)
      end

      def letter?(lookAhead)
        lookAhead =~ /[A-Za-z]/
      end
    end
  end
end