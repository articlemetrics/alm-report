class Facet
  delegate :each, to: :@facets
  attr_reader :facets

  def initialize
    @facets = {}
  end

  def add(facets)
    facets = [facets] unless facets.is_a? Array

    facets.each do |facet|
      @facets.merge! facet
    end
  end

  def remove(facet)
    @facets.delete(facet.keys[0])
  end

  def select(name:, value:)
#    @facets[name][:selected] = true
    @facets[name][value][:selected] = true
  end

  def deselect(name:, value:)
#    @facets[name][:selected] = false
    @facets[name][value][:selected] = false
  end

  def selected
    selected = {}

    @facets.each do |facet, values|
      values.each do |value, properties|
        selected[facet] = value if properties[:selected]
      end
    end

    selected
  end

  def params
    {facets: selected.map do |name, value|
      {name: name, value: value}
    end}
  end
end
