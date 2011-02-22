# == Schema Information
# Schema version: 20110209212927
#
# Table name: sip_accounts
#
#  id            :integer         not null, primary key
#  user_id       :integer
#  auth_name     :string(255)
#  password      :string(255)
#  realm         :string(255)
#  phone_number  :integer
#  sip_server_id :integer
#  sip_proxy_id  :integer
#  created_at    :datetime
#  updated_at    :datetime
#  extension_id  :integer
#  sip_phone_id  :integer
#

class SipAccount < ActiveRecord::Base
  
  belongs_to :sip_server , :validate => true
  belongs_to :sip_proxy  , :validate => true
  belongs_to :sip_phone  , :validate => true
  belongs_to :extension  , :validate => true
  belongs_to :user
  
  validates_uniqueness_of   :auth_name, :scope => :sip_server_id
  validates_presence_of     :sip_server_id
  validates_presence_of     :phone_number
  validates_numericality_of :phone_number
  
  after_validation( :on => :create ) do
    if ! sip_phone_id.nil?
      prov_srv_sip_account_create
    end
    if ! sip_server_id.nil? && ! self.phone_number.nil?
      if ! self.sip_server.config_port.nil?
         create_user_on_sipproxy(  sip_server_id )
         create_alias_on_sipproxy( sip_server_id )
      end
    end
  end
  
  after_validation( :on => :update ) do
    if ! sip_phone_id.nil?
      prov_srv_sip_account_update
    end
    if ((self.auth_name != self.auth_name_was && sip_phone_id_was != nil ) || (sip_phone_id_was != nil \
        && sip_phone_id != sip_phone_id_was))
      delete_last_cantina_account
    end
    if (((self.auth_name_was != self.auth_name) || (self.password != self.password_was)) && self.sip_server_id = self.sip_server_id_was && self.sip_server.config_port != nil)
      update_user_on_sipproxy( sip_server_id, auth_name_was )
    end
    #FIXME - self.sip_server can be nil
    if self.sip_server_id != self.sip_server_id_was && ! self.sip_server.config_port.nil?
      destroy_user_on_sipproxy( sip_server_id_was, auth_name_was )
    end
    if ((self.sip_server_id_was == self.sip_server_id) && \
        ((self.auth_name != self.auth_name_was) || (self.phone_number != self.phone_number_was)))
      update_alias_on_sipproxy( self.sip_server_id, self.auth_name_was, self.phone_number_was )
    end
  end
  
  before_destroy do
    if ! sip_phone_id.nil?
    prov_srv_sip_account_destroy
    end
    if ! sip_server_id.nil?
      if ! self.sip_server.config_port.nil?
        destroy_user_on_sipproxy(    self.sip_server_id_was, self.auth_name_was )
        destroy_dbalias_on_sipproxy( self.sip_server_id_was, self.auth_name_was, self.phone_number_was )
      end
    end
  end
  
  
  #  # http://rubydoc.info/docs/rails/3.0.0/ActiveModel/Dirty
  #  include ActiveModel::Dirty
  #  
  #  define_attribute_methods [:sip_server]
  #  
  #  def sip_server
  #    @sip_server
  #  end
  #  
  #  def sip_server=(val)
  #    name_will_change! unless val == @sip_server
  #    @sip_server = val
  #  end
  #  
  #  def save
  #    @previously_changed = changes
  #    @changed_attributes.clear
  #  end
  
  
  # Returns the corresponding SIP account from Cantina.
  # Returns the CantinaSipAccount if found or nil if not found or
  # false on error.
  #
  def cantina_sip_account
    return cantina_find_sip_account_by_server_and_user(
      self.sip_server ? self.sip_server.name : nil,
      self.auth_name
    )
  end
  
  private
  
  # Create SIP account on the provisioning server.
  #
  def prov_srv_sip_account_create
    prov_srv = 'cantina'  # might want to implement a mock Cantina here or multiple Cantinas
    ret = false
    if self.errors && self.errors.length > 0
      # The SIP account is invalid. Don't even try to create it on the prov. server.
      errors.add( :base, "Will not create invalid SIP account on the provisioning server." )
    else
      case prov_srv
        when 'cantina'
          ret = cantina_sip_account_create
        else
          errors.add( :base, "Provisioning server type #{prov_srv.inspect} not implemented." )
      end
    end
    return ret
  end
  
  # Update SIP account on the provisioning server.
  #
  def prov_srv_sip_account_update
    prov_srv = 'cantina'  # might want to implement a mock Cantina here or multiple Cantinas
    ret = false
    if self.errors && self.errors.length > 0
      # The SIP account is invalid. Don't even try to update it on the prov. server.
      errors.add( :base, "SIP account is invalid. Will not update data on the provisioning server." )
    else
      case prov_srv
        when 'cantina'
          ret = cantina_sip_account_update
        else
          errors.add( :base, "Provisioning server type #{prov_srv.inspect} not implemented." )
      end
    end
    return ret
  end
  
  # Delete SIP account on the provisioning server.
  #
  def prov_srv_sip_account_destroy
    prov_srv = 'cantina'  # might want to implement a mock Cantina here or multiple Cantinas
    ret = false
    case prov_srv
      when 'cantina'
        ret = cantina_sip_account_destroy
      else
        errors.add( :base, "Provisioning server type #{prov_srv.inspect} not implemented." )
    end
    return ret
  end
  
  # Returns the appropriate "site" parameter URL to use for the
  # CantinaSipAccount ActiveResource. Returns nil if the SipPhone
  # corresponding to this SipAccount does not have provisioning.
  #
  def determine_prov_server_resource
    scheme = 'http'
    host   = '0.0.0.0'  # this will not work on purpose
    port   = 0          # this will not work on purpose
    path   = '/'
    if self.sip_phone
      if self.sip_phone.provisioning_server_id.blank?
        logger.debug "SipPhone #{self.sip_phone_id.inspect} has no provisioning server. Alright."
        return nil  # phone without provisioning
      else
        prov_srv = self.sip_phone.provisioning_server
        if prov_srv
          scheme = 'http'  # TODO - https?
          host   = prov_srv.name if ! prov_srv.name.blank?
          port   = prov_srv.port if ! prov_srv.port.blank?
          path   = '/'
        end
      end
    end
    ret = '%s://%s%s%s' % [
      scheme,
      host,
      port.blank? ? '' : ":#{port.to_s}",
      path,
    ]
    logger.debug "SipPhone #{self.sip_phone_id.inspect} has prov. server #{ret.inspect}."
    return ret
  end
  
  # Find a SIP account by SIP server and SIP user on the Cantina
  # provisioning server.
  # Returns the CantinaSipAccount if found or nil if not found or
  # false on error.
  #
  def cantina_find_sip_account_by_server_and_user( sip_server, sip_user )
    logger.debug "Trying to find Cantina SIP account for \"#{sip_user}@#{sip_server}\" ..."
    begin
      cantina_resource = determine_prov_server_resource()
      if ! cantina_resource
        # SipPhone has no provisioning server.
        return nil
      else
        CantinaSipAccount.set_resource( cantina_resource )
        cantina_sip_accounts = CantinaSipAccount.all()
        # GET "/sip_accounts.xml" - #OPTIMIZE - The Cantina API does not let us do more advanced queries so we have to get all SIP accounts.
        # FIXME see sipproxy API
        if cantina_sip_accounts
          cantina_sip_accounts.each { |cantina_sip_account|
            if (cantina_sip_account.registrar .to_s == sip_server .to_s) \
            && (cantina_sip_account.auth_user .to_s == auth_name  .to_s)
              logger.debug "Found CantinaSipAccount ID #{cantina_sip_account.id}."
              return cantina_sip_account
              break
            end
          }
        end
        logger.debug "CantinaSipAccount not found."
        return nil
      end
    rescue Errno::ECONNREFUSED => e
      return false
    end
  end
  
  # Create SIP account on the Cantina provisioning server.
  #
  def cantina_sip_account_create
    begin
      cantina_resource = determine_prov_server_resource()
      if ! cantina_resource
        return true
      else
        CantinaSipAccount.set_resource( cantina_resource )
        cantina_sip_account = CantinaSipAccount.create({
          :name            => "a SIP account from Gemeinschaft (#{Time.now.to_i}-#{self.object_id})",
          :auth_user       => self.auth_name,
          :user            => self.phone_number,
          :password        => self.password,
          :realm           => self.realm,
          :phone_id        => (self.sip_phone ? self.sip_phone.phone_id : nil),
          :registrar       => (self.sip_server ? self.sip_server.name : nil),
          :registrar_port  => nil,
          :sip_proxy       => (self.sip_proxy ? self.sip_proxy.name : nil),
          :sip_proxy_port  => nil,
          :registration_expiry_time => 300,
          :dtmf_mode       => 'rfc2833',
        })
        log_active_record_errors_from_remote( cantina_sip_account )
        return true
      end
    rescue Errno::ECONNREFUSED => e
      logger.warn "Failed to connect to Cantina provisioning server. (#{e.class}, #{e.message})"
      errors.add( :base, "Failed to connect to Cantina provisioning server." )
      return false
    end
    
    if ! cantina_sip_account.valid?
      errors.add( :base, "Failed to create SIP account on Cantina provisioning server. (Reason:\n" +
      get_active_record_errors_from_remote( cantina_sip_account ).join(",\n") +
        ")" )
      return false
    end
  end
  
  # Update SIP account on the Cantina provisioning server.
  #
  def cantina_sip_account_update
    sip_server_was = self.sip_server_id_was ? SipServer.find( self.sip_server_id_was ) : nil
    cantina_sip_account = cantina_find_sip_account_by_server_and_user(
      (sip_server_was ? sip_server_was.name : nil),
      self.auth_name_was
    )
    
    case cantina_sip_account
      when false
        errors.add( :base, "Failed to connect to Cantina provisioning server." )
        return false
      when nil
        # create instead
        return cantina_sip_account_create
      else
        if ! cantina_sip_account.update_attributes({
          :auth_user       => self.auth_name,
          :user            => self.phone_number,
          :password        => self.password,
          :realm           => self.realm,
          :phone_id        => (self.sip_phone ? self.sip_phone.phone_id : nil),
          :registrar       => (self.sip_server ? self.sip_server.name : nil),
          :registrar_port  => nil,
          :sip_proxy       => (self.sip_proxy ? self.sip_proxy.name : nil),
          :sip_proxy_port  => nil,
          :registration_expiry_time => 300,
          :dtmf_mode       => 'rfc2833',
        })
        log_active_record_errors_from_remote( cantina_sip_account )
        errors.add( :base, "Failed to update SIP account on Cantina provisioning server. (Reason:\n" +
        get_active_record_errors_from_remote( cantina_sip_account ).join(",\n") +
          ")" )
        return false
      end
    end
    return true
  end
  
  # Delete SIP account on the Cantina provisioning server.
  #
  def cantina_sip_account_destroy
    sip_server_was = self.sip_server_id_was ? SipServer.find( self.sip_server_id_was ) : nil
    cantina_sip_account = cantina_find_sip_account_by_server_and_user(
      (sip_server_was ? sip_server_was.name : nil),
      self.auth_name_was
    )
    
    case cantina_sip_account
      when false
        errors.add( :base, "Failed to connect to Cantina provisioning server." )
        return false
      when nil
        # no action required
      else
        if ! cantina_sip_account.destroy
          errors.add( :base, "Failed to delete SIP account on Cantina provisioning server. (Reason:\n" +
          get_active_record_errors_from_remote( cantina_sip_account ).join(",\n") +
            ")" )
          return false
        end
    end
    return true
  end
  
  # Delete SipAccount on Cantina when Phone has changed.
  #
  def delete_last_cantina_account
    prov_server = SipPhone.find(sip_phone_id_was).provisioning_server
    CantinaSipAccount.set_resource( "http://#{prov_server.name}:#{prov_server.port}" )
    #OPTIMIZE - set_resource() wants a path "/", and .port can be blank.
    cantina_sip_accounts = CantinaSipAccount.all
    if cantina_sip_accounts
      found_c_accounts = cantina_sip_accounts.each { |cantina_sip_account|
        if (cantina_sip_account.registrar .to_s == self.sip_server .to_s) \
        && (cantina_sip_account.auth_user .to_s == self.auth_name  .to_s)
          logger.debug "Found CantinaSipAccount ID #{cantina_sip_account.id}."
          break
        end
      }
    end
    delete_c_account = found_c_accounts.collect {|a| a.id}.to_enum.first
    if ! CantinaSipAccount.find(delete_c_account).destroy
      errors.add( :base, "Failed to delete SIP account on Cantina provisioning server. (Reason:\n" +
      get_active_record_errors_from_remote( delete_c_account ).join(",\n") +
        ")" )
    end
  end
  
  # Create user on "SipProxy" proxy manager.
  #
  def create_user_on_sipproxy( p_id )
    server = SipServer.find(p_id)
    if server.config_port.nil?
      # TODO errormessage
      return false
    else
      SipproxySubscriber.set_resource( "http://#{server.name}:#{server.config_port}" )
      #OPTIMIZE - set_resource() wants a path "/", and .config_port can be blank(?).
      sipproxy_subscriber = SipproxySubscriber.create(
        :username   =>  self.auth_name,
        :domain     =>  self.sip_server.name,
        :password   =>  self.password,
       :ha1        =>  Digest::MD5.hexdigest( "#{self.auth_name}:#{self.sip_server.name}:#{self.password}" )
      )
      if ! sipproxy_subscriber.valid?
        errors.add( :base, "Failed to create user account on sipproxy server. (Reason:\n" +
        get_active_record_errors_from_remote( sipproxy_subscriber ).join(",\n") +
          ")" )
      end
    end
  end
  
  # Delete user on "SipProxy" proxy manager.
  #
  def destroy_user_on_sipproxy( p_id, p_authname )
    begin
      server = SipServer.find(p_id)
      if server.config_port.nil?
        # TODO errormessage
        return false
      else
        SipproxySubscriber.set_resource( "http://#{server.name}:#{server.config_port}" )
        #OPTIMIZE - set_resource() wants a path "/", and .config_port can be blank(?).
        destroy_subscriber = SipproxySubscriber.find( :first, :params => { 'username' => p_authname.to_s })
        if ! destroy_subscriber.destroy
          errors.add( :base, "Failed to destroy user account on sipproxy server. (Reason:\n" +
          get_active_record_errors_from_remote( sipproxy_subscriber ).join(",\n") +
            ")" )
          # TODO error message
        else
          return true
        end
      end
    rescue Errno::ECONNREFUSED => e
      logger.warn "Failed to connect to sipproxy server. (#{e.class}, #{e.message})"
      errors.add( :base, "Failed to connect to sipproxy server." )
      return false
    end
  end
  
  # Update user on "SipProxy" proxy manager.
  #
  def update_user_on_sipproxy( p_id, p_authname )
    server = SipServer.find(p_id)
    if server.config_port.nil?
      # TODO errormessage
      return false
    else
      SipproxySubscriber.set_resource( "http://#{server.name}:#{server.config_port}" )
      #OPTIMIZE - set_resource() wants a path "/", and .config_port can be blank(?).
      update_subscriber = SipproxySubscriber.find( :first, :params => { 'username' => p_authname.to_s })
      sipproxy_subscriber = update_subscriber.update_attributes(
        :username   =>  self.auth_name,
        :domain     =>  self.sip_server.name,
        :password   =>  self.password,
       	:ha1        =>  Digest::MD5.hexdigest( "#{self.auth_name}:#{self.sip_server.name}:#{self.password}" )
      )
      if ! sipproxy_subscriber
        errors.add( :base, "Failed to create user account on sipproxy server. (Reason:\n" +
        get_active_record_errors_from_remote( sipproxy_subscriber ).join(",\n") +
          ")" )
      end
    end
  end
  
  # Create alias on "SipProxy" proxy manager.
  #
  def create_alias_on_sipproxy( p_id )
    server = SipServer.find(p_id)
    if server.config_port.nil?
      # TODO errormessage
      return false
    else
      SipproxyDbalias.set_resource( "http://#{server.name}:#{server.config_port}" )
      #OPTIMIZE - set_resource() wants a path "/", and .config_port can be blank(?).
      sipproxy_dbalias = SipproxyDbalias.create(
        :username       =>  self.auth_name,
        :domain         =>  self.sip_server.name,
        :alias_username =>  self.phone_number,
        :alias_domain   =>  self.sip_server.name
      )
      if ! sipproxy_dbalias.valid?
        errors.add( :base, "Failed to create alias on sipproxy server. (Reason:\n" +
        get_active_record_errors_from_remote( sipproxy_dbalias ).join(",\n") +
          ")" )
      end
    end
  end
  
  # Update alias on "SipProxy" proxy manager.
  #
  def update_alias_on_sipproxy( p_id, p_name, p_alias )
    server = SipServer.find(p_id)
    if server.config_port.nil?
      # TODO errormessage
      return false
    else
      SipproxyDbalias.set_resource( "http://#{server.name}:#{server.config_port}" )
      #OPTIMIZE - set_resource() wants a path "/", and .config_port can be blank(?).
      update_dbalias = SipproxyDbalias.find( :first, :params => {'username'=> "#{p_name}", 'alias_username' => "#{p_alias}"} )
      sipproxy_dbalias = update_dbalias.update_attributes(
        :username       =>  self.auth_name,
        :domain         =>  self.sip_server.name,
        :alias_username =>  self.phone_number,
        :alias_domain   =>  self.sip_server.name
      )
      if ! sipproxy_dbalias
        errors.add( :base, "Failed to update dbalias on sipproxy server. (Reason:\n" +
        get_active_record_errors_from_remote( sipproxy_dbalias ).join(",\n") +
          ")" )
      end
    end
  end
  
  # Delete dbalias on "SipProxy" proxy manager.
  #
  def destroy_dbalias_on_sipproxy( p_id, p_authname, p_alias )
    begin
      server = SipServer.find(p_id)
      if server.config_port.nil?
        # TODO errormessage
        return false
      else
        SipproxyDbalias.set_resource( "http://#{server.name}:#{server.config_port}" )
        #OPTIMIZE - set_resource() wants a path "/", and .config_port can be blank(?).
        destroy_dbalias = SipproxyDbalias.find( :first, :params => { 'username' => p_authname.to_s, 'alias_username' => p_alias.to_s })
        if ! destroy_dbalias.destroy
          errors.add( :base, "Failed to destroy dbalias on sipproxy server. (Reason:\n" +
          get_active_record_errors_from_remote( sipproxy_dbalias ).join(",\n") +
            ")" )
          # TODO error message
        else
          return true
        end
      end
    rescue Errno::ECONNREFUSED => e
      logger.warn "Failed to connect to sipproxy server. (#{e.class}, #{e.message})"
      errors.add( :base, "Failed to connect to sipproxy server." )
      return false
    end
  end
  
  # Log validation errors from the remote model.
  #
  def log_active_record_errors_from_remote( ar )
    if ar.respond_to?(:errors) && ar.errors.kind_of?(Hash)
      logger.info "----------------------------------------------------------"
      logger.info "Errors for #{ar.class} from Cantina:"
      ar.errors.each_pair { |attr, errs|
        logger.info "  :#{attr.to_s}"
        if errs.kind_of?(Array) && errs.length > 0
          errs.each { |msg|
            logger.info "    " + (attr == :base ? '' : ":#{attr.to_s} ") + "#{msg}"
          }
        end
      }
      logger.info "----------------------------------------------------------"
    end
  end
  
  # Get validation errors from the remote model.
  #
  def get_active_record_errors_from_remote( ar )
    ret = []
    if ar.respond_to?(:errors) && ar.errors.kind_of?(Hash)
      ar.errors.each_pair { |attr, errs|
        if errs.kind_of?(Array) && errs.length > 0
          errs.each { |msg|
            ret << ( '' + (attr == :base ? '' : "#{attr.to_s} ") + "#{msg}" )
          }
        end
      }
    end
    return ret
  end
  
end
