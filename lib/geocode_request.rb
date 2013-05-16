require "net/http"
require "open-uri"
require "json"

# Exception class thrown if there is an error communicating with the geocode servers.
class GeocodeError < StandardError
end


# Interface to servers that return latitude and longitude for a street or city address.
class GeocodeRequest
  
  @@GOOGLE_URL = "http://maps.googleapis.com/maps/api/geocode/json"
  
  # Maximum queries per second to send to Google.  See comment for rate_limit.
  @@MAX_QPS = 1.0
  
  # Unix timestamp of when the last query was sent.  Used by rate_limit.
  @@last_query = 0.0
  
  
  # According to https://developers.google.com/maps/documentation/geocoding/
  # you can issue up to 2500 requests/day for free.  However, I've found that
  # the API will claim you are over the limit if you pound it rapidly, even if
  # well below that total number.  So this method checks to see if we've
  # waited at least a certain amount, and sleeps if necessary to enforce that.
  def self.rate_limit
    interval = Time.now.to_f - @@last_query
    wait = 1.0 / @@MAX_QPS
    if interval < wait
      Rails.logger.warn("QPS limit to geocoding service exceeded.  Sleeping before making request...")
      sleep(wait - interval)
    end
  end
  
  
  # Returns a [latitude, longitude] tuple upon successful geocoding of the given address.
  # Raises GeocodeError if the address cannot be geocoded.
  def self.geocode(address)
    rate_limit
    
    url = "#{@@GOOGLE_URL}?address=#{URI::encode(address)}&sensor=false"
    resp = Net::HTTP.get_response(URI.parse(url))
    @@last_query = Time.now.to_f
    raise GeocodeError, "Server returned #{resp.code}: " + resp.body unless resp.code == "200"
    json = JSON.parse(resp.body)
    raise GeocodeError, "#{address} received status #{json["status"]}" unless json["status"] == "OK"
    results = json["results"]
    
    # Occasionally the API will return more than 1 result, if there is some
    # ambiguity.  Hopefully the first is the right one!
    raise GeocodeError, "#{address} received no results" unless results.length > 0
    location = results[0]["geometry"]["location"]
    return [location["lat"], location["lng"]]
  end
  
  
  # Attempts to geocode the addresses passed in.  Returns a map from input address
  # to a two-element array, the first element of which is latitude and the second
  # of which is longitude.
  #
  # TODO: unfortunately, there don't seem to be any good APIs that allow you
  # to send multiple addresses in a single request (bulk or batch queries).
  # I did find some, but I had never heard of the companies providing them, which
  # gives me pause since I don't want us to have to change this if our provider
  # goes belly-up.  Therefore, the current implementation of this method sends one
  # request per address in the input and could take a very long time!
  def self.bulk_geocode(addresses)
    results = {}
    addresses.each {|address| results[address] = GeocodeRequest.geocode(address)}
  end
  
end
