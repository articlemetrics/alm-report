
require "test_helper"

class IpRangesTest < ActiveSupport::TestCase
  
  test "is_internal_ip_test" do
    assert(IpRanges.is_internal_ip("127.0.0.1"))
    assert(IpRanges.is_internal_ip("***REMOVED***98"))
    assert(IpRanges.is_internal_ip("***REMOVED***97"))
    assert(IpRanges.is_internal_ip("***REMOVED***126"))
    assert(IpRanges.is_internal_ip("***REMOVED***217"))
    assert(IpRanges.is_internal_ip("***REMOVED***222"))
    assert(IpRanges.is_internal_ip("10.38.70.212"))
    assert(IpRanges.is_internal_ip("172.20.13.127"))
    assert(IpRanges.is_internal_ip("192.168.14.2"))
    
    assert(!IpRanges.is_internal_ip("37.134.13.56"))
    assert(!IpRanges.is_internal_ip("***REMOVED***127"))
    assert(!IpRanges.is_internal_ip("***REMOVED***216"))
    assert(!IpRanges.is_internal_ip("172.32.1.1"))
    assert(!IpRanges.is_internal_ip("192.169.22.178"))
  end
  
end
