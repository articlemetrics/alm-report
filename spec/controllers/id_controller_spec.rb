require "spec_helper"

describe IdController do
  it "validates dois" do
    IdController.validate_doi(nil).should eq(nil)
    IdController.validate_doi("").should eq(nil)
    IdController.validate_doi("foo").should eq(nil)
    IdController.validate_doi("info:doi/10.1371/journal.pone.003337").
      should eq(nil)
    IdController.validate_doi("0.1371/journal.pmed.1000077").should eq(nil)
    IdController.validate_doi("10.1371/journal.pmed.100007").should eq(nil)
    IdController.validate_doi("info:doi/10.1371/journal.ffoo.0033299").
      should eq(nil)
    IdController.validate_doi("info:doi/10.1371/journa.pmed.0010052").
      should eq(nil)

    IdController.validate_doi("info:doi/10.1371/journal.pone.0049349").
      should eq("10.1371/journal.pone.0049349")

    IdController.validate_doi("10.1371/journal.pmed.1000077").
      should eq("10.1371/journal.pmed.1000077")

    # Currents DOIs.  These are handled slightly differently.
    IdController.validate_doi(
      "10.1371/currents.dis.ad70cd1c8bc585e9470046cde334ee4b"
    ).should eq("10.1371/currents.dis.ad70cd1c8bc585e9470046cde334ee4b")

    IdController.validate_doi(
      "info:doi/10.1371/currents.tol.53ba26640df0ccaee75bb165c8c26288"
    ).should eq("10.1371/currents.tol.53ba26640df0ccaee75bb165c8c26288")

    IdController.validate_doi("doi/10.1371/currents.RRN1226").
      should eq("10.1371/currents.RRN1226")

    IdController.validate_doi("10.1371/4f8d4eaec6af8").
      should eq("10.1371/4f8d4eaec6af8")

    IdController.validate_doi("info:doi/10.1371/5035add8caff4").
      should eq("10.1371/5035add8caff4")

    IdController.validate_doi("doi/10.1371/4fd1286980c08").
      should eq("10.1371/4fd1286980c08")

  end
end