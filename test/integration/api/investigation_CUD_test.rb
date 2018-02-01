require 'test_helper'

class InvestigationCUDTest < ActionDispatch::IntegrationTest
  include AuthenticatedTestHelper

  def setup

    admin = Factory.create(:admin)
     @current_user = admin.user
    @current_user.password = 'blah'

    @min_project = Factory(:min_project)
    @min_project.title = 'Fred'

    @max_project = Factory(:max_project)
    @max_project.title = 'Bert'


    # log in
    post '/session', login: admin.user.login, password: admin.user.password

    @@template_dir = File.join(Rails.root, 'test', 'fixtures',
                               'files', 'json', 'templates')
    template_file = File.join(@@template_dir, 'post_min_investigation.json.erb')
    template = ERB.new(File.read(template_file))
    namespace = OpenStruct.new({:project_ids => [@min_project.id, @max_project.id], :r => InvestigationCUDTest.method(:render_erb)} )
    template_result = template.result(namespace.instance_eval {binding})
    @to_post = JSON.parse(template_result)
  end

  def self.render_erb (path, locals)
    content = File.read(File.join(@@template_dir, path))
    template = ERB.new(content)
    h = locals
    h[:r] = method(:render_erb)
    namespace = OpenStruct.new(h)
    template.result(namespace.instance_eval {binding})
  end

  def test_create

    extra_attributes = {}
    extra_attributes[:policy] = BaseSerializer::convert_policy Factory(:private_policy)
    extra_attributes = extra_attributes.with_indifferent_access

    person_id = @current_user.person.id
    extra_relationships = {}
    extra_relationships[:submitter] = JSON.parse "{\"data\" : [{\"id\" : \"#{person_id}\", \"type\" : \"people\"}]}"
    extra_relationships[:people] = JSON.parse "{\"data\" : [{\"id\" : \"#{person_id}\", \"type\" : \"people\"}]}"
    extra_relationships = extra_relationships.with_indifferent_access

    # debug note: responds with redirect 302 if not really logged in.. could happen if database resets and has no users
    assert_difference('Investigation.count') do
      post '/investigations.json', @to_post
      assert_response :success
    end
    # check some of the content
    h = JSON.parse(response.body)

    @to_post['data']['attributes'].each do |key, value|
      assert_equal value, h['data']['attributes'][key]
    end

    h['data']['attributes'].each do |key, value|
      if @to_post['data']['attributes'].has_key? key
        assert_equal value, @to_post['data']['attributes'][key]
      elsif extra_attributes.has_key? key
        assert_equal value, extra_attributes[key]
      elsif value.blank?
        # Should be OK
        else
        warn("Unexpected attribute [#{key}]=#{value}")
      end
    end


    @to_post['data']['relationships'].each do |key, value|
      assert_equal value, h['data']['relationships'][key]
    end

    h['data']['relationships'].each do |key, value|
      if @to_post['data']['relationships'].has_key? key
        assert_equal value, @to_post['data']['relationships'][key]
      elsif extra_relationships.has_key? key
        assert_equal value, extra_relationships[key]
      elsif value.blank?
        # Should be OK
      elsif value['data'].blank?
        # Should be OK
      else
        warn("Unexpected relationship [#{key}]=#{value}")
      end
    end


  end

  def test_update
    post '/investigations.json', @to_post
    assert_response :success

    h = JSON.parse(response.body)
    investigation_id = h['data']['id']

    patch_file = File.join(Rails.root, 'test', 'fixtures', 'files', 'json', 'templates', 'patch_investigation.json.erb')
    the_patch = ERB.new(File.read(patch_file))
    namespace = OpenStruct.new(id: investigation_id)
    @to_patch = JSON.parse(the_patch.result(namespace.instance_eval { binding } ) )

    assert_no_difference( 'Investigation.count') do
      patch "/investigations/#{investigation_id}.json", @to_patch
      assert_response :success
    end

    h = JSON.parse(response.body)

    if @to_patch['data'].key? 'attributes'
      @to_patch['data']['attributes'].each do |key, value|
        assert_equal value, h['data']['attributes'][key]
      end
    end

    if @to_patch['data'].key? 'relationships'
      @to_patch['data']['relationships'].each do |key, value|
        assert_equal value, h['data']['relationships'][key]
      end
    end

    if (@to_post['data'].key? 'attributes') && (@to_patch['data'].key? 'attributes')
      @to_post['data']['attributes'].each do |key, value|
        unless @to_patch['data']['attributes'].key? key
          assert_equal value, h['data']['attributes'][key]
        end
      end
    end

    if (@to_post['data'].key? 'relationships') && (@to_patch['data'].key? 'relationships')
      @to_post['data']['relationships'].each do |key, value|
        unless @to_patch['data']['relationships'].key? key
          assert_equal value, h['data']['relationships'][key]
        end
      end
    end
  end

  def test_create_with_id
    post_clone = JSON.parse(JSON.generate(@to_post))
    post_clone['data']['id'] = '100000000'

    assert_no_difference ('Investigation.count') do
      post '/investigations.json', post_clone
      assert_response :unprocessable_entity
      assert_match 'A POST request is not allowed to specify an id', response.body
    end
  end

  def test_create_wrong_type
    post_clone = JSON.parse(JSON.generate(@to_post))
    post_clone['data']['type'] = 'wrong'
    assert_no_difference ('Investigation.count') do
      post '/investigations.json', post_clone
      assert_response :unprocessable_entity
      assert_match "The specified data:type does not match the URL's object (wrong vs. investigations)", response.body
    end
  end

  def test_create_missing_type
    post_clone = JSON.parse(JSON.generate(@to_post))
    post_clone['data'].delete('type')
    assert_no_difference ('Investigation.count') do
      post '/investigations.json', post_clone
      assert_response :unprocessable_entity
      assert_match 'A POST/PUT request must specify a data:type', response.body
    end
  end

  def test_update_wrong_id
    post '/investigations.json', @to_post
    assert_response :success

    h = JSON.parse(response.body)
    investigation_id = h['data']['id']

    patch_file = File.join(Rails.root, 'test', 'fixtures', 'files', 'json', 'templates', 'patch_investigation.json.erb')
    the_patch = ERB.new(File.read(patch_file))
    namespace = OpenStruct.new(id: '100000000')
    @to_patch = JSON.parse(the_patch.result(namespace.instance_eval { binding }))

    assert_no_difference ('Investigation.count') do
      patch "/investigations/#{investigation_id}.json", @to_patch
      assert_response :unprocessable_entity
    end
  end

  def test_update_wrong_type
    post '/investigations.json', @to_post
    assert_response :success

    h = JSON.parse(response.body)
    investigation_id = h['data']['id']

    patch_file = File.join(Rails.root, 'test', 'fixtures', 'files', 'json', 'templates', 'patch_investigation.json.erb')
    the_patch = ERB.new(File.read(patch_file))
    namespace = OpenStruct.new
    @to_patch = JSON.parse(the_patch.result(namespace.instance_eval { binding }))
    @to_patch['data']['type'] = 'wrong'

    assert_no_difference ('Investigation.count') do
      patch "/investigations/#{investigation_id}.json", @to_patch
      assert_response :unprocessable_entity
      assert_match "The specified data:type does not match the URL's object (wrong vs. investigations)", response.body
    end
  end

  def test_update_missing_type
    post '/investigations.json', @to_post
    assert_response :success

    h = JSON.parse(response.body)
    investigation_id = h['data']['id']

    patch_file = File.join(Rails.root, 'test', 'fixtures', 'files', 'json', 'templates', 'patch_investigation.json.erb')
    the_patch = ERB.new(File.read(patch_file))
    namespace = OpenStruct.new
    @to_patch = JSON.parse(the_patch.result(namespace.instance_eval { binding }))
    @to_patch['data'].delete('type')
    assert_no_difference ('Investigation.count') do
      patch "/investigations/#{investigation_id}.json", @to_patch
      assert_response :unprocessable_entity
      assert_match 'A POST/PUT request must specify a data:type', response.body
    end
  end

  def test_delete
    post '/investigations.json', @to_post
    assert_response :success

    h = JSON.parse(response.body)
    investigation_id = h['data']['id']
    assert_difference ('Investigation.count'), -1 do
      delete "/investigations/#{investigation_id}.json"
      assert_response :success
    end

    get "/investigations/#{investigation_id}.json"
    assert_response :not_found
  end
end