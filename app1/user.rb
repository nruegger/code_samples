class User < ActiveRecord::Base

  # --- Relations ---------------------
  has_many :boards, dependent: :destroy
  has_many :widgets, dependent: :destroy
  has_many :sources, dependent: :destroy

  # --- Callbacks ---------------------

  def oauth_token_decrypted
    @oauth_token_decrypted ||= Encryptor.decrypt(read_attribute(:oauth_token)) if read_attribute(:oauth_token)
  end

  def oauth_token=(str)
    @oauth_token_decrypted = nil
    write_attribute(:oauth_token, Encryptor.encrypt(str))
  end

  def refresh_token_decrypted
    @refresh_token_decrypted ||= Encryptor.decrypt(read_attribute(:refresh_token)) if read_attribute(:refresh_token)
  end

  def refresh_token=(str)
    @refresh_token_decrypted = nil
    write_attribute(:refresh_token, Encryptor.encrypt(str))
  end

  # assigns information pulled from omniauth gem
  def self.from_omniauth(auth, params, session)
    user = where(provider: auth.provider, uid: auth.uid).first_or_initialize
    return if !user.id && !Settings.registration_enabled
    user.name = auth.info.name
    user.email = auth.info.email
    user.image = auth.info.image
    user.oauth_token = auth.credentials.token
    user.refresh_token = auth.credentials.refresh_token if auth.credentials.refresh_token.present?
    user.oauth_expires_at = Time.at(auth.credentials.expires_at)
    user.save!

    user.update_sources(auth, params, session)
    user.init_first_board

    user
  end

  def update_sources(auth, params, session)
    # Support only google
    provider = 'google'
    source = self.sources.where(email: auth.info.email, provider: provider).first_or_initialize
    source.name = auth.info.name
    source.uid = auth.uid
    source.refresh_token = auth.credentials.refresh_token if auth.credentials.refresh_token.present?
    source.oauth_token = auth.credentials.token
    source.oauth_expires_at = Time.at(auth.credentials.expires_at)
    source.save!
    source.after_connect(params, session)
    source
  end

  def self.register_user_microsoft(params, session)
    token_data = Sources::Microsoft.get_token_from_code(params[:code])
    jwt = Sources::Microsoft.get_jwt_from_id_token(token_data.params['id_token'])
    email = jwt['email'] || jwt['preferred_username']
    user = where(provider: :microsoft, email: email).first_or_initialize
    return if !user.id && !Settings.registration_enabled
    user.uid = ''
    user.name = jwt['name']
    user.oauth_token = token_data.token
    user.refresh_token = token_data.refresh_token
    user.oauth_expires_at = DateTime.current + token_data.expires_in.seconds
    user.save!

    user.update_microsoft_source(params, session, {token_data: token_data, jwt: jwt})
    user.init_first_board
    user
  end

  def update_microsoft_source(params, session, options = {})
    token_data = options[:token_data] || Sources::Microsoft.get_token_from_code(params[:code])
    jwt = options[:jwt] || Sources::Microsoft.get_jwt_from_id_token(token_data.params['id_token'])
    email = jwt['email'] || jwt['preferred_username']
    source = self.sources.where(provider: :microsoft, email: email).first_or_initialize
    source.uid = ''
    source.name = jwt['name']
    source.oauth_token = token_data.token
    source.refresh_token = token_data.refresh_token
    source.oauth_expires_at = DateTime.current + token_data.expires_in.seconds
    source.data['personal_account'] = jwt['tid'] == '9188040d-6c67-4c5b-b112-36a304b66dad'
    source.save!

    source.after_connect(params, session)
    source
  end

  # Set current user
  def self.current
    Thread.current[:user]
  end

  def self.current=(user)
    Thread.current[:user] = user
  end

  # Boards
  DEFAULT_BOARD_KEY = 'user_%s_default_board'

  def init_first_board
    board = boards.first
    return if board
    self.default_board_id = boards.create_default_for(self).id
    true
  end

  def default_board
    Board.find(self.default_board_id)
  end

  def default_board_id
    @default_board_id ||= Rails.cache.fetch(DEFAULT_BOARD_KEY % self.id) { boards.last.id }
  end

  def default_board_id=(board_id)
    Rails.cache.write(DEFAULT_BOARD_KEY % self.id, board_id)
    @default_board_id = board_id
  end

  # Widgets
  def list_widgets
    Widget.where(user_id: self.id)
  end

  def remove_widget(widget)
    self.list_boards.each do |board|
      board.widgets.delete(widget.id) if board.widgets.include?(widget.id)
      board.save!
    end
    widget.destroy
  end

  def to_hash
    {
        id: self.id,
        name: self.name,
        email: self.email,
        image: self.image,
        sources: sources.order('id ASC').map(&:to_hash),
        show_tutorial: self.show_tutorial,
        show_welcome_screen: self.show_welcome_screen,
        time_zone: current_time_zone,
        socket_chanel_id: socket_chanel_id,
    }
  end

  def current_time_zone
    self.time_zone || Constants::TimeZone::DEFAULT
  end

  def change_board_order(board_ids)
    return if board_ids.blank?
    return unless board_ids.is_a?(Array)
    board_ids.each_with_index do |board_id, index|
      board = self.boards.where(id: board_id.to_i).first
      board.update_attribute(:order_id, index) if board
    end
  end

  def socket_chanel_id
    salt = 'VGhpcyBpcyBsaW5lIG9uZQpUaGlzIG'
    Base64.encode64(id.to_s + salt).gsub(/\W/, '')
  end
end