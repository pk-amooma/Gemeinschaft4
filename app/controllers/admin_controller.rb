class AdminController < ApplicationController
  
  # Let's make sure that we have a database.
  rescue_from ActiveRecord::StatementInvalid, :with => :rescue_missing
  
  # The first time you have to setup an admin account.
  before_filter :check_if_admin_account_exists
  
  before_filter :authenticate_user!
  
  def index
    if SipServer.count == 0 || SipProxy.count == 0
      respond_to do |format|
        format.html { redirect_to(admin_setup_index_path) }
      end
      
    else
      @number_of_users         = User.count
      @number_of_sip_accounts  = SipAccount.count
      @number_of_phones        = Phone.count
      @number_of_sip_proxies   = SipProxy.count
      @number_of_sip_servers   = SipServer.count
      @number_of_extensions    = Extension.count
      
      respond_to do |format|
        format.html
      end
    end
  end
  
  private
  
  def rescue_missing
    redirect_to( '/db_migrate_missing.html' )
  end
  
  def check_if_admin_account_exists
    if User.count == 0
      redirect_to(new_admin_setup_path)
    end
  end
  
end
