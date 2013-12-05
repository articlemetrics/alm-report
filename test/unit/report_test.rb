
require "test_helper"

class IpRangesTest < ActiveSupport::TestCase

  test "test_build_subject_string" do
    data = [
        "/Biology and life sciences/Genetics/Genomics/Genome analysis/Genomic libraries",
        "/Biology and life sciences/Organisms/Animals/Invertebrates/Arthropoda/Insects/Drosophila/Drosophila melanogaster",
        "/Biology and life sciences/Evolutionary biology/Organismal evolution",
        "/Research and analysis methods/Molecular biology techniques/Sequencing techniques/Sequence analysis",
        "/Biology and life sciences/Genetics/Genomics/Genome evolution",
        "/Biology and life sciences/Computational biology/Genome analysis/Genomic libraries",
        "/Biology and life sciences/Genetics/Heredity/Homozygosity",
        "/Biology and life sciences/Microbiology/Microbial genomics/Bacterial genomics",
        "/Biology and life sciences/Evolutionary biology/Molecular evolution/Genome evolution",
        "/Biology and life sciences/Genetics/Genomics/Microbial genomics/Bacterial genomics",
        "/Biology and life sciences/Genetics/Genomics/Animal genomics/Invertebrate genomics",
        "/Research and analysis methods/Model organisms/Animal models/Drosophila melanogaster",
        "/Biology and life sciences/Computational biology/Genome evolution",
        "/Biology and life sciences/Microbiology/Bacteriology/Bacterial genomics"]
    assert_equal("Bacterial genomics,Drosophila melanogaster,Genome evolution,Genomic libraries,Homozygosity,Invertebrate genomics,Organismal evolution,Sequence analysis",
        Report.build_subject_string(data))
  end

end
