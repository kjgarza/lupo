require 'rails_helper'

describe "doi:index_by_month", elasticsearch: true do
  include ActiveJob::TestHelper
  include_context "rake"

  ENV['FROM_DATE'] = "2018-01-04"
  ENV['UNTIL_DATE'] = "2018-08-05"

  let!(:doi)  { create_list(:doi, 10) }
  let(:output) { "Queued indexing for DOIs updated from 2018-01-01 until 2018-08-31.\n" }

  it "prerequisites should include environment" do
    expect(subject.prerequisites).to include("environment")
  end

  it "should run the rake task" do
    expect(capture_stdout { subject.invoke }).to eq(output)
  end

  it "should enqueue an DoiIndexByMonthJob" do
    expect {
      capture_stdout { subject.invoke }
    }.to change(enqueued_jobs, :size).by(8)
    expect(enqueued_jobs.last[:job]).to be(DoiIndexByMonthJob)
  end
end

describe "doi:index", elasticsearch: true do
  include ActiveJob::TestHelper
  include_context "rake"

  let!(:doi)  { create_list(:doi, 10) }
  let(:output) { "Queued indexing for DOIs updated from 2018-01-04 - 2018-08-05.\n" }

  it "prerequisites should include environment" do
    expect(subject.prerequisites).to include("environment")
  end

  it "should run the rake task" do
    expect(capture_stdout { subject.invoke }).to eq(output)
  end
end