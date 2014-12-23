require "spec_helper"

describe Facet do
  it "adds a facet" do
    @facet = Facet.new

    first = {
      name: :article_type
      value: { "research article" =>
        { "count" => 10}
      }
    }

    @facet.add(first)

    Facet.facets.should eq {first.name => first.value}
  end
end
