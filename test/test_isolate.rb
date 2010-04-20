require "isolate/test"

require "isolate"

class TestIsolate < Isolate::Test
  WITH_HOE = "test/fixtures/with-hoe"

  def teardown
    Isolate.instance.disable if Isolate.instance
    super
  end

  def test_self_env
    assert_equal "development", Isolate.env

    ENV["RAILS_ENV"] = "foo"

    assert_equal "foo", Isolate.env

    ENV["RAILS_ENV"] = nil
    ENV["RACK_ENV"]  = "bar"

    assert_equal "bar", Isolate.env

    ENV["RACK_ENV"]    = nil
    ENV["ISOLATE_ENV"] = "baz"

    assert_equal "baz", Isolate.env
  end

  def test_self_gems
    assert_nil Isolate.instance

    Isolate.gems WITH_HOE, :versioned => false do
      gem "hoe"
    end

    refute_nil Isolate.instance
    assert_equal File.expand_path(WITH_HOE), Isolate.instance.path
    assert_equal "hoe", Isolate.instance.entries.first.name
  end
end
