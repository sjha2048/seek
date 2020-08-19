#default project and institution
unless Project.find_by_title('Default Meeting') && Institution.find_by_title('CompModelMatch')
  project = Project.find_or_create_by(title:'Default Meeting')
  institution = Institution.find_or_create_by(title:'CompModelMatch', country: 'US')

  disable_authorization_checks do
    project.institutions << institution
    project.save!
  end

  puts 'Seeded default project'
end
