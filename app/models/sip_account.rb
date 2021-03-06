class SipAccount < ActiveRecord::Base
  
  belongs_to :sip_server       , :validate => true
  belongs_to :sip_proxy        , :validate => true
  belongs_to :voicemail_server , :validate => true
  belongs_to :phone            , :validate => true
  belongs_to :user             , :validate => true
  
  has_many :sip_account_to_extensions, :dependent => :destroy
  has_many :extensions, :through => :sip_account_to_extensions
  
  acts_as_list :scope => :user
  
  validate_username         :auth_name
  validates_uniqueness_of   :auth_name, :case_sensitive => false, :scope => :sip_server_id
  
  validates_presence_of     :sip_server
  validates_presence_of     :sip_proxy
  validates_presence_of     :voicemail_server , :if => Proc.new { |me| me.voicemail_server_id }
  validates_presence_of     :phone            , :if => Proc.new { |me| me.phone_id }
  validates_presence_of     :user             , :if => Proc.new { |me| me.user_id }
  
  validate_password         :password
  
    
  validates_numericality_of :voicemail_pin,
    :if => Proc.new { |sip_account| ! sip_account.voicemail_server_id.blank? },
    :only_integer => true,
    :greater_than_or_equal_to => 1000,
    :message => "must be all digits and greater than 1000"
  validates_inclusion_of    :voicemail_pin,
    :in => [ nil ],
    :if => Proc.new { |sip_account| sip_account.voicemail_server_id.blank? },
    :message => "must not be set if the SIP account does not have a voicemail server."

  after_validation( :on => :create ) do
    if (! self.sip_server_id.nil?) && (! self.sip_proxy_id.nil?) && (self.sip_proxy.is_local?)
      create_subscriber()
    end
  end
  
  after_validation( :on => :update ) do
    if (! self.sip_server_id.nil?) && (! self.sip_proxy_id.nil?) && (self.sip_proxy.is_local?)
      update_subscriber()
    else
      delete_subscriber()
    end
  end
  
  before_destroy do
    delete_subscriber()
  end
  
  def create_subscriber()
    subscriber = Subscriber.create(
      :username   =>  self.auth_name,
      :domain     =>  self.sip_server.host,
      :password   =>  self.password,
      :ha1        =>  Digest::MD5.hexdigest( "#{self.auth_name}:#{self.sip_server.host}:#{self.password}" )
    )
    if ! subscriber.valid?
      errors.add( :base, "Failed to create subscriber")
    end
  end
  
  def update_subscriber()
    subscriber_update = Subscriber.find_by_username( self.auth_name_was )
    if (! subscriber_update.nil?)
      subscriber = subscriber_update.update_attributes(
        :username   =>  self.auth_name,
        :domain     =>  self.sip_server.host,
        :password   =>  self.password,
        :ha1        =>  Digest::MD5.hexdigest( "#{self.auth_name}:#{self.sip_server.host}:#{self.password}" )
      )
      if ! subscriber
        errors.add( :base, "Failed to update subscriber")
      end
    else
      create_subscriber()
    end
  end
  
  def delete_subscriber()
    if (! self.sip_proxy_id_was.nil?) && (SipProxy.find_by_id( self.sip_proxy_id_was).is_local?)
      subscriber_delete = Subscriber.find_by_username( self.auth_name_was )
      if subscriber_delete
        if ! subscriber_delete.destroy
          errors.add( :base, "Failed to delete subscriber")
        end
      end
    end
  end
end
