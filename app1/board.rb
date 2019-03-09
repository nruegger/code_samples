class Board < ActiveRecord::Base

  # --- Relations ---------------------
  belongs_to :user
  has_many :widgets, dependent: :destroy


  def self.create_default_for(user)
    board = user.boards.new(name: 'Default', widgets: [])
    source = user.sources.first
    if source.provider == 'google'
      ['File', 'Email', 'Calendar', 'Contact'].each do |type|
        widget = Widget.create(name: "#{type}s", user_id: user.id, source_ids: [source.id], widget_type: type.downcase)
        board.widgets.push widget
      end
    elsif source.provider == 'evernote'
      widget = Widget.create(name: 'Notes', user_id: user.id, source_ids: [source.id], widget_type: :note)
      board.widgets.push widget
    elsif source.provider == 'dropbox'
      widget = Widget.create(name: 'File', user_id: user.id, source_ids: [source.id], widget_type: :file)
      board.widgets.push widget
    elsif source.provider == 'microsoft'
      ['Email', 'Calendar', 'Contact', 'Note', 'File'].each do |type|
        widget = Widget.create(name: "#{type}s", user_id: user.id, source_ids: [source.id], widget_type: type.downcase)
        board.widgets.push widget
      end
    end
    board.save!
    board
  end

  def add_widget(widget)
    self.widgets << widget
    self.save!
  end

  def hash_key
    Digest::MD5.hexdigest("board_#{self.id}")
  end

  def update_widget_order(widget_ids)
    return if widget_ids.blank?
    return unless widget_ids.is_a?(Array)
    widget_ids.each_with_index do |widget_id, index|
      widget = self.widgets.where(id: widget_id.to_i).first
      widget.update_attribute(:order_id, index) if widget
    end
  end

  def to_hash
    {
        id: self.id,
        name: self.name,
        default: user.default_board_id == self.id,
        hash_key: hash_key,
    }
  end
end