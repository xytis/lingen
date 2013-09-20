require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Lingen::Rule do
  describe '#new' do
    it "creates a rule object by parsing simple rule string" do
      input = "A -> B"
      rule = Lingen::Rule.new(input, /A|B/)
      rule.seed.should == "A"
      p rule
    end
  end
end

describe Lingen::Module do
  it "should exist" do
  end
end
