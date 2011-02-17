Factory.define :sip_account do |f|
  f.sequence(:user_id) { |n| n }
  f.sequence(:auth_name) { |n| "testauth_name#{n}" }
  f.sequence(:password) { |n| "testpassword#{n}" }
  f.sequence(:realm) { |n| "testrealm#{n}" }
  f.sequence(:phone_number) { |n| n }
  
  f.association :sip_server
  f.association :sip_proxy
end