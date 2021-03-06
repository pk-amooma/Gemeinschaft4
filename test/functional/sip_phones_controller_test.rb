require 'test_helper'

class SipPhonesControllerTest < ActionController::TestCase
  
  # Devise Test Helpers
  # see https://github.com/plataformatec/devise
  include Devise::TestHelpers
  
  setup do
    @sip_phone = Factory.create(:sip_phone)
    
    an_admin_username = 'admin1'
    @admin_user = User.where( :username => an_admin_username ).first
    assert_not_nil @admin_user, "This tests needs user #{an_admin_username.inspect}"
    
    #@expected_http_status_if_not_allowed = 403
    @expected_http_status_if_not_allowed = 302
  end
  
  
   
  test "should not get index (not an admin)" do
    get :index
    assert_response( @expected_http_status_if_not_allowed )
  end
  
  
  test "should get new" do
    sign_in :user, @admin_user
    get :new
    assert_response :success
    sign_out @admin_user
  end
  
  test "should not get new (not an admin)" do
    get :new
    assert_response( @expected_http_status_if_not_allowed )
  end
  
  
  
  
  test "should show sip_phone" do
    sign_in :user, @admin_user
    get :show, :id => @sip_phone.to_param
    assert_response :success
    sign_out @admin_user
  end
  
  test "should not show sip_phone (not an admin)" do
    get :show, :id => @sip_phone.to_param
    assert_response( @expected_http_status_if_not_allowed )
  end
  
  
    
  test "should not get edit (not an admin)" do
    get :edit, :id => @sip_phone.to_param
    assert_response( @expected_http_status_if_not_allowed )
  end
  
  
  
  test "should not update sip_phone (not an admin)" do
    put :update, :id => @sip_phone.to_param, :sip_phone => @sip_phone.attributes
    assert_response( @expected_http_status_if_not_allowed )
  end
  
  
  
  test "should not destroy sip_phone (not an admin)" do
    assert_no_difference('SipPhone.count') {
      delete :destroy, :id => @sip_phone.to_param
    }
    assert_response( @expected_http_status_if_not_allowed )
  end
  
  
end
