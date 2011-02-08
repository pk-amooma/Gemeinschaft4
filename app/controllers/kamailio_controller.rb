class KamailioController < ApplicationController
  
  before_filter :authenticate_user!
  
  def index
    @sip_accounts = SipAccount.all
    
    respond_to do |format|
      format.txt      
    end
  end
  
end
