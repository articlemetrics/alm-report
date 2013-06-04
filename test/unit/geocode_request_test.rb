
require "test_helper"

class GeocodeRequestTest < ActiveSupport::TestCase
  
  def parse_assert(expected, affiliate)
    location, institution = GeocodeRequest.parse_location_from_affiliate(affiliate)
    assert_equal(expected[0], location)
    assert_equal(expected[1], institution)
  end
  
  
  test "parse_location_from_affiliate_test" do
    assert_nil(GeocodeRequest.parse_location_from_affiliate(""))
    assert_nil(GeocodeRequest.parse_location_from_affiliate("foo"))
    assert_nil(GeocodeRequest.parse_location_from_affiliate("foo,bar"))
    
    parse_assert(["Waimanalo, Hawaii, United States of America",
        "National Oceanic and Atmospheric Administration (NOAA), National Ocean Service, National Centers for Coastal Ocean Science-Biogeography Team and The Oceanic Institute"],
        "National Oceanic and Atmospheric Administration (NOAA), National Ocean Service, National Centers for Coastal Ocean Science-Biogeography Team and The Oceanic Institute, Waimanalo, Hawaii, United States of America")
    parse_assert(["Starnberg, Germany", "Max-Planck-Institut fur Verhaltensphysiologie Seewiesen"],
        "Max-Planck-Institut fur Verhaltensphysiologie Seewiesen, Starnberg, Germany")
    parse_assert(["Townsville, Queensland, Australia", "Australian Institute of Marine Science"],
        "Australian Institute of Marine Science, Townsville, Queensland, Australia")
    parse_assert(["Henan, China", "Henan Geological Museum, Zhengzhou"],
        "Henan Geological Museum, Zhengzhou, Henan, China")
  end
  
end
