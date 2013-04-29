
require "test_helper"

class IdControllerTest < ActiveSupport::TestCase
  
  test "validate_doi_test" do
    assert_nil(IdController.validate_doi(nil))
    assert_nil(IdController.validate_doi(""))
    assert_nil(IdController.validate_doi("foo"))
    assert_nil(IdController.validate_doi("info:doi/10.1371/journal.pone.003337"))
    assert_nil(IdController.validate_doi("0.1371/journal.pmed.1000077"))
    assert_nil(IdController.validate_doi("10.1371/journal.pmed.100007"))
    assert_nil(IdController.validate_doi("info:doi/10.1371/journal.ffoo.0033299"))
    assert_nil(IdController.validate_doi("info:doi/10.1371/journa.pmed.0010052"))
    
    assert_equal("10.1371/journal.pone.0049349",
        IdController.validate_doi("info:doi/10.1371/journal.pone.0049349"))
    assert_equal("10.1371/journal.pmed.1000077",
        IdController.validate_doi("10.1371/journal.pmed.1000077"))
  end
  
end
