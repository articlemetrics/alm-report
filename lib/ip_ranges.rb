require "ipaddr"

# Module to keep track of PLOS-internal IP ranges.
# TODO: make this IPv6-aware if necessary.
module IpRanges
  
  # RFC 1918 private network ranges that should always be considered internal.
  @@private_ranges = [
      IPAddr.new("10.0.0.0/8"),
      IPAddr.new("172.16.0.0/12"),
      IPAddr.new("192.168.0.0/16")
      ]
  
  # Returns true if the given IP should be considered an internal PLOS IP.
  def self.is_internal_ip(ip)
    if ip == "127.0.0.1"
      return true
    end
    ranges = []
    ranges += @@private_ranges
    APP_CONFIG["internal_ip_ranges"].each {|range| ranges << IPAddr.new(range)}
    ranges.each{|range| return true if range.include?(ip)}
    false
  end
  
end
