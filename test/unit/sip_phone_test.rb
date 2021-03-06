require 'test_helper'

class SipPhoneTest < ActiveSupport::TestCase
  # testing sip_phone requires node to be accessible
  
  should "not be valid without a phone_id if it has a node_id" do
    node = Factory.create( :node )
    assert ! Factory.build( :sip_phone, {
      :node_id                => node.id,
      :phone_id               => nil,
    }).valid?
  end
  
  #should "not be possible to create with a phone_id that does not exist on the node" do
  #  node = Factory.create( :node )
  #  p = SipPhone.new({
  #    :node_id                => node.id,
  #    :phone_id               => 818181,
  #  })
  #  assert ! p.save
  #end
  
  
  should "be valid with a phone_id if it has a node_id" do
    node = Factory.create( :node )
    
    #TODO Remove ActiveResource.
    ActiveResource::HttpMock.reset!
    ActiveResource::HttpMock.respond_to { |mock|
      cantina_phone = {
        :id              => 99999,
        :mac_address     => '000000000001',
        :phone_model_id  => 0,
        :ip_address      => '0.0.0.1',
        :last_ip_address => '0.0.0.1',
        :http_user       => '',
        :http_password   => '',
      }
      mock.get   "/phones/99999.xml", {}, # GET = show
        cantina_phone.to_xml( :root => "phone" ), 200, {}
    }
    
    assert Factory.build( :sip_phone, {
      :node_id                => node.id,
      :phone_id               => 99999,
    }).valid?
    
    #puts "Asserting that the mock received the expected request (GET /phones/99999.xml) from the model ..."
    idx = ActiveResource::HttpMock.requests.index(
      ActiveResource::Request.new(
        :get, "/phones/99999.xml", nil, { "Accept"=>"application/xml" } )
    )
    assert_not_equal( nil, idx )
    
    ActiveResource::HttpMock.reset!
  end
  
  should "not be valid without a node_id" do
    assert ! SipPhone.new({
      :node_id                => nil,
      :phone_id               => nil,
    }).valid?
  end
  
  should "not be possible to set a node_id that does not exist" do
    node = Factory.create( :node )
    node_id = node.id
    node.destroy
    assert ! Factory.build( :sip_phone,
      :node_id => node_id ).valid?
  end
  
  should "be unique per node" do
    node = Factory.create( :node )
    
    mocked_cantina_phone = {
      :id              => 88888,
      :mac_address     => '000000000001',
      :phone_model_id  => 0,
      :ip_address      => '0.0.0.1',
      :last_ip_address => '0.0.0.1',
      :http_user       => '',
      :http_password   => '',
    }
    
    #TODO Remove ActiveResource.
    ActiveResource::HttpMock.reset!
    ActiveResource::HttpMock.respond_to { |mock|
      mock.get   "/phones/88888.xml", {}, # GET = show
        mocked_cantina_phone.to_xml( :root => "phone" ), 200, {}
    }
    
    sip_phone = Factory.create( :sip_phone, {
      :node_id                => node.id,
      :phone_id               => 88888,
    })
    
    #puts "Asserting that the mock received the expected request (GET /phones/88888.xml) from the model ..."
    idx = ActiveResource::HttpMock.requests.index(
      ActiveResource::Request.new(
        :get, "/phones/88888.xml", nil, { "Accept"=>"application/xml" } )
    )
    assert_not_equal( nil, idx )
    
    #ActiveResource::HttpMock.reset!
    #ActiveResource::HttpMock.respond_to { |mock|
    #  mock.get   "/phones/88888.xml", {}, # GET = show
    #    mocked_cantina_phone.to_xml( :root => "phone" ), 200, {}
    #}
    
    assert ! Factory.build( :sip_phone, {
      :node_id                => sip_phone.node_id,
      :phone_id               => sip_phone.phone_id,
    }).valid?
    
    ##puts "Asserting that the mock received the expected request (GET /phones/88888.xml) from the model ..."
    #idx = ActiveResource::HttpMock.requests.index(
    #  ActiveResource::Request.new(
    #    :get, "/phones/88888.xml", nil, { "Accept"=>"application/xml" } )
    #)
    #assert_not_equal( nil, idx )
    
    #ActiveResource::HttpMock.reset!
  end
  
end
