
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
        
    # Currents DOIs.  These are handled slightly differently.
    assert_equal("10.1371/currents.dis.ad70cd1c8bc585e9470046cde334ee4b",
        IdController.validate_doi("10.1371/currents.dis.ad70cd1c8bc585e9470046cde334ee4b"))
    assert_equal("10.1371/currents.tol.53ba26640df0ccaee75bb165c8c26288",
        IdController.validate_doi("info:doi/10.1371/currents.tol.53ba26640df0ccaee75bb165c8c26288"))
    assert_equal("10.1371/currents.RRN1226",
        IdController.validate_doi("doi/10.1371/currents.RRN1226"))
    assert_equal("10.1371/4f8d4eaec6af8", IdController.validate_doi("10.1371/4f8d4eaec6af8"))
    assert_equal("10.1371/5035add8caff4",
        IdController.validate_doi("info:doi/10.1371/5035add8caff4"))
    assert_equal("10.1371/4fd1286980c08", IdController.validate_doi("doi/10.1371/4fd1286980c08"))
  end
  
end
