
require "test_helper"

class GeocodeRequestTest < ActiveSupport::TestCase
  
  test "parse_location_from_affiliate_test" do
    assert_nil(GeocodeRequest.parse_location_from_affiliate(""))
    assert_nil(GeocodeRequest.parse_location_from_affiliate("foo"))
    assert_nil(GeocodeRequest.parse_location_from_affiliate("foo,bar"))
    
    assert_equal("Waimanalo, Hawaii, United States of America",
        GeocodeRequest.parse_location_from_affiliate(
        "National Oceanic and Atmospheric Administration (NOAA), National Ocean Service, National Centers for Coastal Ocean Science-Biogeography Team and The Oceanic Institute, Waimanalo, Hawaii, United States of America"))
    assert_equal("Starnberg, Germany",
        GeocodeRequest.parse_location_from_affiliate(
        "Max-Planck-Institut fur Verhaltensphysiologie Seewiesen, Starnberg, Germany"))
    assert_equal("Townsville, Queensland, Australia",
        GeocodeRequest.parse_location_from_affiliate(
        "Australian Institute of Marine Science, Townsville, Queensland, Australia"))
  end
  
end
