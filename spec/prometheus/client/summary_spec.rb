# encoding: UTF-8

require 'prometheus/client'
require 'prometheus/client/summary'
require 'examples/metric_example'

describe Prometheus::Client::Summary do
  # Reset the data store
  before do
    Prometheus::Client.config.data_store = Prometheus::Client::DataStores::Synchronized.new
  end

  let(:expected_labels) { [] }

  let(:summary) do
    Prometheus::Client::Summary.new(:bar,
                                    docstring: 'bar description',
                                    labels: expected_labels)
  end

  it_behaves_like Prometheus::Client::Metric do
    let(:type) { Hash }
  end

  describe '#initialization' do
    it 'raise error for `quantile` label' do
      expect do
        described_class.new(:bar, docstring: 'bar description', labels: [:quantile])
      end.to raise_error Prometheus::Client::LabelSetValidator::ReservedLabelError
    end
  end

  describe '#observe' do
    it 'records the given value' do
      expect do
        summary.observe(5)
      end.to change { summary.get }.
        from({ "count" => 0.0, "sum" => 0.0 }).
        to({ "count" => 1.0, "sum" => 5.0 })
    end

    it 'raise error for quantile labels' do
      expect do
        summary.observe(5, labels: { quantile: 1 })
      end.to raise_error Prometheus::Client::LabelSetValidator::InvalidLabelSetError
    end

    it 'raises an InvalidLabelSetError if sending unexpected labels' do
      expect do
        summary.observe(5, labels: { foo: 'bar' })
      end.to raise_error Prometheus::Client::LabelSetValidator::InvalidLabelSetError
    end

    context "with a an expected label set" do
      let(:expected_labels) { [:test] }

      it 'observes a value for a given label set' do
        expect do
          expect do
            summary.observe(5, labels: { test: 'value' })
          end.to change { summary.get(labels: { test: 'value' })["count"] }
        end.to_not change { summary.get(labels: { test: 'other' })["count"] }
      end

      it 'can pre-set labels using `with_labels`' do
        expect { summary.observe(2) }
          .to raise_error(Prometheus::Client::LabelSetValidator::InvalidLabelSetError)
        expect { summary.with_labels(test: 'value').observe(2) }.not_to raise_error
      end
    end

    context "with non-string label values" do
      let(:summary) do
        described_class.new(:foo,
                            docstring: 'foo description',
                            labels: [:foo])
      end

      it "converts labels to strings for consistent storage" do
        summary.observe(5, labels: { foo: :label })
        expect(summary.get(labels: { foo: 'label' })["count"]).to eq(1.0)
      end

      context "and some labels preset" do
        let(:summary) do
          described_class.new(:foo,
                              docstring: 'foo description',
                              labels: [:foo, :bar],
                              preset_labels: { foo: :label })
        end

        it "converts labels to strings for consistent storage" do
          summary.observe(5, labels: { bar: :label })
          expect(summary.get(labels: { foo: 'label', bar: 'label' })["count"]).to eq(1.0)
        end
      end
    end
  end

  describe '#get' do
    let(:expected_labels) { [:foo] }

    before do
      summary.observe(3, labels: { foo: 'bar' })
      summary.observe(5.2, labels: { foo: 'bar' })
      summary.observe(13, labels: { foo: 'bar' })
      summary.observe(4, labels: { foo: 'bar' })
    end

    it 'returns a value which responds to #sum and #total' do
      expect(summary.get(labels: { foo: 'bar' })).
        to eql({ "count" => 4.0, "sum" => 25.2 })
    end
  end

  describe '#values' do
    let(:expected_labels) { [:status] }

    it 'returns a hash of all recorded summaries' do
      summary.observe(3, labels: { status: 'bar' })
      summary.observe(5, labels: { status: 'foo' })

      expect(summary.values).to eql(
        { status: 'bar' } => { "count" => 1.0, "sum" => 3.0 },
        { status: 'foo' } => { "count" => 1.0, "sum" => 5.0 },
      )
    end
  end

  describe '#init_label_set' do
    let(:expected_labels) { [:status] }

    it 'initializes the metric for a given label set' do
      expect(summary.values).to eql({})

      summary.init_label_set(status: 'bar')
      summary.init_label_set(status: 'foo')

      expect(summary.values).to eql(
        { status: 'bar' } => { "count" => 0.0, "sum" => 0.0 },
        { status: 'foo' } => { "count" => 0.0, "sum" => 0.0 },
      )
    end
  end

  describe '#init_label_set' do
    let(:expected_labels) { [:foo] }
    before { summary.observe(2, labels: { foo: 'bar' }) }

    it 'deletes the metric for a given label set' do
      expect(summary.values).to include({ foo: 'bar' } => { "count" => 1.0, "sum" => 2.0 })

      summary.purge_label_set(foo: 'bar')

      expect(summary.values).to_not include({ foo: 'bar' } => { "count" => 1.0, "sum" => 2.0 })
    end
  end
end
