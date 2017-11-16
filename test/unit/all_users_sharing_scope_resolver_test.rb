require 'test_helper'

class AllUsersSharingScopeResolver < ActiveSupport::TestCase
  def setup
    @resolver = Seek::Permissions::AllUsersSharingScopeResolver.new
  end

  # should leave it unchanged
  test 'no sharing scope' do
    df = Factory(:data_file, policy: Factory(:public_download_and_no_custom_sharing))
    assert_empty df.policy.permissions
    refute_empty df.projects
    assert_nil df.policy.sharing_scope
    assert_equal Policy::ACCESSIBLE, df.policy.access_type

    updated_df = @resolver.resolve(df)
    assert_nil updated_df.policy.sharing_scope
    assert_equal Policy::ACCESSIBLE, updated_df.policy.access_type
  end

  # should set the scope to nil, but do nothing else
  test 'sharing scope but not ALL_USERS' do
    other_project = Factory(:project)
    presentation = Factory(:presentation,
                           policy: Factory(:policy,
                                           access_type: Policy::VISIBLE,
                                           sharing_scope: Policy::EVERYONE,
                                           permissions: [Factory(:permission, contributor: other_project, access_type: Policy::ACCESSIBLE)]))
    assert_equal 1, (permissions = presentation.policy.permissions).count
    assert_equal 1, (projects = presentation.projects).count
    refute_includes projects, other_project
    assert_equal Policy::EVERYONE, presentation.policy.sharing_scope
    assert_equal Policy::VISIBLE, presentation.policy.access_type
    permission = permissions.first
    assert_equal other_project, permission.contributor
    assert_equal Policy::ACCESSIBLE, permission.access_type

    updated_presentation = @resolver.resolve(presentation)

    assert_nil updated_presentation.policy.sharing_scope
    assert_equal Policy::VISIBLE, updated_presentation.policy.access_type
    assert_equal 1, (permissions = updated_presentation.policy.permissions).count
    assert_equal 1, (projects = updated_presentation.projects).count
    assert_equal Policy::VISIBLE, updated_presentation.policy.access_type
    permission = permissions.first
    assert_equal other_project, permission.contributor
    assert_equal Policy::ACCESSIBLE, permission.access_type
  end

  test 'no original permissions' do
    sop = Factory(:sop, policy: Factory(:public_download_and_no_custom_sharing, sharing_scope: Policy::ALL_USERS))
    assert_empty sop.policy.permissions
    assert_equal 1, (projects = sop.projects).count
    assert_equal Policy::ALL_USERS, sop.policy.sharing_scope
    assert_equal Policy::ACCESSIBLE, sop.policy.access_type

    updated_sop = @resolver.resolve(sop)

    assert_nil updated_sop.policy.sharing_scope
    assert_equal Policy::PRIVATE, updated_sop.policy.access_type
    assert_equal 1, updated_sop.policy.permissions.count
    permission = updated_sop.policy.permissions.first
    project = projects.first
    assert_equal project, permission.contributor
    assert_equal Policy::ACCESSIBLE, permission.access_type
  end

  test 'existing permission but different project' do
    other_project = Factory(:project)
    presentation = Factory(:presentation,
                           policy: Factory(:policy,
                                           access_type: Policy::VISIBLE,
                                           sharing_scope: Policy::ALL_USERS,
                                           permissions: [Factory(:permission, contributor: other_project, access_type: Policy::ACCESSIBLE)]))
    assert_equal 1, (permissions = presentation.policy.permissions).count
    assert_equal 1, (projects = presentation.projects).count
    refute_includes projects, other_project
    assert_equal Policy::ALL_USERS, presentation.policy.sharing_scope
    assert_equal Policy::VISIBLE, presentation.policy.access_type
    permission = permissions.first
    assert_equal other_project, permission.contributor
    assert_equal Policy::ACCESSIBLE, permission.access_type

    updated_presentation = @resolver.resolve(presentation)

    assert_nil updated_presentation.policy.sharing_scope
    assert_equal Policy::PRIVATE, updated_presentation.policy.access_type
    assert_equal 2, updated_presentation.policy.permissions.count
    assert_includes updated_presentation.policy.permissions, permission
    assert_equal [other_project, projects.first], updated_presentation.policy.permissions.collect(&:contributor)
    assert_equal [Policy::ACCESSIBLE, Policy::VISIBLE], updated_presentation.policy.permissions.collect(&:access_type)
  end

  test 'existing permission same project same access_type' do
    project = Factory(:project)
    model = Factory(:model,
                    policy: Factory(:policy,
                                    access_type: Policy::VISIBLE,
                                    sharing_scope: Policy::ALL_USERS,
                                    permissions: [Factory(:permission, contributor: project, access_type: Policy::VISIBLE)]),
                    projects: [project])

    assert_equal 1, (permissions = model.policy.permissions).count
    assert_equal 1, (projects = model.projects).count
    assert_equal [project], projects
    assert_equal Policy::ALL_USERS, model.policy.sharing_scope
    assert_equal Policy::VISIBLE, model.policy.access_type
    permission = permissions.first
    assert_equal project, permission.contributor
    assert_equal Policy::VISIBLE, permission.access_type

    updated_model = @resolver.resolve(model)

    assert_nil updated_model.policy.sharing_scope
    assert_equal Policy::PRIVATE, updated_model.policy.access_type
    assert_equal 1, updated_model.policy.permissions.count
    permission = updated_model.policy.permissions.first
    assert_equal project, permission.contributor
    assert_equal Policy::VISIBLE, permission.access_type
  end

  test 'existing permission same project higher access_type' do
    # should update the permission to give the higher access
    project = Factory(:project)
    investigation = Factory(:investigation,
                            policy: Factory(:policy,
                                            access_type: Policy::ACCESSIBLE,
                                            sharing_scope: Policy::ALL_USERS,
                                            permissions: [Factory(:permission, contributor: project, access_type: Policy::VISIBLE)]),
                            projects: [project])

    assert_equal 1, (permissions = investigation.policy.permissions).count
    assert_equal 1, (projects = investigation.projects).count
    assert_equal [project], projects
    assert_equal Policy::ALL_USERS, investigation.policy.sharing_scope
    assert_equal Policy::ACCESSIBLE, investigation.policy.access_type
    permission = permissions.first
    assert_equal project, permission.contributor
    assert_equal Policy::VISIBLE, permission.access_type

    updated_investigation = @resolver.resolve(investigation)

    assert_nil updated_investigation.policy.sharing_scope
    assert_equal Policy::PRIVATE, updated_investigation.policy.access_type
    assert_equal 1, updated_investigation.policy.permissions.count
    permission = updated_investigation.policy.permissions.first
    assert_equal project, permission.contributor
    assert_equal Policy::ACCESSIBLE, permission.access_type
  end

  test 'existing permission same project lower access_type' do
    # should keep the existing higher access
    project = Factory(:project)
    investigation = Factory(:investigation,
                            policy: Factory(:policy,
                                            access_type: Policy::VISIBLE,
                                            sharing_scope: Policy::ALL_USERS,
                                            permissions: [Factory(:permission, contributor: project, access_type: Policy::ACCESSIBLE)]),
                            projects: [project])

    assert_equal 1, (permissions = investigation.policy.permissions).count
    assert_equal 1, (projects = investigation.projects).count
    assert_equal [project], projects
    assert_equal Policy::ALL_USERS, investigation.policy.sharing_scope
    assert_equal Policy::VISIBLE, investigation.policy.access_type
    permission = permissions.first
    assert_equal project, permission.contributor
    assert_equal Policy::ACCESSIBLE, permission.access_type

    updated_investigation = @resolver.resolve(investigation)

    assert_nil updated_investigation.policy.sharing_scope
    assert_equal Policy::PRIVATE, updated_investigation.policy.access_type
    assert_equal 1, updated_investigation.policy.permissions.count
    permission = updated_investigation.policy.permissions.first
    assert_equal project, permission.contributor
    assert_equal Policy::ACCESSIBLE, permission.access_type
  end

  test 'multiple projects and people' do
    project1 = Factory(:project)
    project2 = Factory(:project)
    project3 = Factory(:project)
    another_project = Factory(:project)
    person = Factory(:person)
    permission1 = Factory(:permission, contributor: person, access_type: Policy::EDITING)
    permission2 = Factory(:permission, contributor: project1, access_type: Policy::MANAGING)
    permission3 = Factory(:permission, contributor: project2, access_type: Policy::VISIBLE)
    df = Factory(:data_file, projects: [project1, project3], policy: Factory(:policy,
                                                                             sharing_scope: Policy::ALL_USERS,
                                                                             access_type: Policy::ACCESSIBLE,
                                                                             permissions: [permission1, permission2, permission3]))
    assert_equal [project1, project3], df.projects
    assert_equal Policy::ALL_USERS, df.policy.sharing_scope
    assert_equal Policy::ACCESSIBLE, df.policy.access_type
    assert_equal 3, df.policy.permissions.count

    updated_df = @resolver.resolve(df)
    assert_nil updated_df.policy.sharing_scope
    assert_equal Policy::PRIVATE, updated_df.policy.access_type
    assert_equal 4, updated_df.policy.permissions.count
    assert_equal [person, project1, project2, project3], updated_df.policy.permissions.collect(&:contributor)
    assert_equal [Policy::EDITING, Policy::MANAGING, Policy::ACCESSIBLE, Policy::ACCESSIBLE], updated_df.policy.permissions.collect(&:access_type)
  end
end