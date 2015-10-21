class TestRun
  include Mongoid::Document

  field :conformance
  field :destination_conformance
  field :date, type: DateTime
  field :is_multiserver, type: Boolean, default: false
  field :status, type: String, default: "pending"
  field :progress, type: Float, default: 0.0

  belongs_to :server, :class_name => "Server"
  belongs_to :destination_server, :class_name => "Server"
  belongs_to :user
  field :nightly, type: Boolean, default: false
  has_many :test_results, autosave: true

  # Execute a set of tests.  Tests can be a single test, or an enumeration of tests
  def execute(tests)

    tests = Array(tests)
    client1 = FHIR::Client.new(self.server.url)
    if self.server.oauth_token_opts
      client1.client = self.server.get_oauth2_client
      client1.use_oauth2_auth = true
    end
    # client2 = FHIR::Client.new(result.test_run.destination_server.url) if result.test_run.is_multiserver
    # TODO: figure out multi server
    client2 = nil

    executor = Crucible::Tests::Executor.new(client1, client2)

    unless self.server.available?
      self.status = "unavailable"
      self.save

      return false
    end

    self.status = "running"

    tests.each_with_index do |t, i|

      begin
        Rails.logger.debug "\t #{i}/#{tests.length}: #{self.server.name}(#{self.server.url})"

        test = executor.find_test(t.title)
        val = nil
        if t.resource_class?
          val = test.execute(t.resource_class.constantize)[0]["#{t.title}_#{t.resource_class.split("::")[1]}"][:tests]
        else
          val = test.execute()[0][t.title][:tests]
        end
        result = TestResult.new
        result.test = t
        result.server = self.server
        result.has_run = true
        result.result = val

        self.progress = (i + 1.0) / tests.length
        self.test_results << result
        self.status = "complete" if i + 1 == tests.length
        self.save

        yield(result, i, tests.length) if block_given?

      rescue Exception => e
        self.status = "error"
        self.save
        Rails.logger.debug e.message
        Rails.logger.debug e.backtrace
        return false
      end
    end

    true

  end

  def finish()

    self.server.aggregate(self)
    compliance = server.get_compliance()

    summary = Summary.new({server_id: self.server.id, test_run: self, compliance: compliance, generated_at: Time.now})
    self.server.summary = summary
    self.server.percent_passing = (compliance['passed'].to_f / ([compliance['total'].to_f || 0, 1].max)) * 100.0
    summary.save!

    self.server.save!

    self.status = "finished"
    self.save

    return summary
  end

  def serializable_hash(options = nil)
    hash = super(options)
    hash['id'] = hash.delete('_id').to_s if(hash.has_key?('_id'))
    hash
  end

end

