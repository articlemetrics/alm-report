require "ipaddr"

# Module to keep track of PLOS-internal IP ranges.
module IpRanges
  
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
    @@private_ranges.each {|range| return true if range.include?(ip)}
    
    # Based on http://intranet.plos.org/it/ops/priv/SitePages/Network%20Topology.aspx
    last_octet = ip.split(".")[-1].to_i
    if ip.start_with?("***REMOVED***")  # SF Office
      return (***REMOVED***).cover?(last_octet)
    elsif ip.start_with?("***REMOVED***")  # UK Office
      return (***REMOVED***).cover?(last_octet)
    else
      return false
    end
  end
  
end
