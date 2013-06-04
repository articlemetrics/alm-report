require "net/http"
require "open-uri"
require "json"

# Exception class thrown if there is an error communicating with the geocode servers.
class GeocodeError < StandardError
end


# Interface to servers that return latitude and longitude for a street or city address.
class GeocodeRequest
  
  @@GOOGLE_URL = "http://maps.googleapis.com/maps/api/geocode/json"
  
  # Unix timestamp of when the last query was sent.  Used by rate_limit.
  @@last_query = 0.0
  
  
  # According to https://developers.google.com/maps/documentation/geocoding/
  # you can issue up to 2500 requests/day for free.  However, I've found that
  # the API will claim you are over the limit if you pound it rapidly, even if
  # well below that total number.  So this method checks to see if we've
  # waited at least a certain amount, and sleeps if necessary to enforce that.
  def self.rate_limit
    interval = Time.now.to_f - @@last_query
    wait = 1.0 / APP_CONFIG["max_geocode_qps"]
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
  
  
  # Contains countries where we have affiliate data of the form "City, Province, Country".
  # For all other countries the affiliate is in the form "Province, Country".
  @@COUNTRIES_WITH_CITIES = Set.new([
      "Australia",
      "Canada",
      "United States of America",
      ])
  
  # Parses the author affiliates field in the article XML to retrieve the location
  # of the author.  Returns a tuple of location and the intitution name (the latter
  # just being everything found before the location), or nil if the affiliate
  # cannot be parsed.
  #
  # TODO: maybe put this somewhere else.  It doesn't really belong here.
  def self.parse_location_from_affiliate(affiliate)
    fields = affiliate.split(",")
    fields.map { |location| location.strip! }
    if fields.length >= 3
      offset = @@COUNTRIES_WITH_CITIES.include?(fields[-1]) ? 3 : 2
      return [fields[-offset, offset].join(", "), fields[0, fields.length - offset].join(", ")]
    else
      nil
    end
  end
  
end
