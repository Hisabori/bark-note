require 'xcodeproj'
project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
app = project.targets.find { |t| t.name == 'Runner' }
unless project.targets.any? { |t| t.name == 'DepartureWidget' }
  group = project.main_group.new_group('LiveActivity', 'LiveActivity')
  attrs = group.new_file('DepartureAttributes.swift')
  widget = group.new_file('DepartureWidget.swift')
  group.new_file('Info.plist')
  app.source_build_phase.add_file_reference(attrs)
  target = project.new_target(:app_extension, 'DepartureWidget', :ios, '16.2')
  target.source_build_phase.add_file_reference(attrs)
  target.source_build_phase.add_file_reference(widget)
  target.build_configurations.each do |config|
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.barknote.barkNote.DepartureWidget'
    config.build_settings['PRODUCT_NAME'] = 'DepartureWidget'
    config.build_settings['PRODUCT_MODULE_NAME'] = 'DepartureWidget'
    config.build_settings['INFOPLIST_FILE'] = 'LiveActivity/Info.plist'
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['MARKETING_VERSION'] = '0.11.0'
    config.build_settings['CURRENT_PROJECT_VERSION'] = '14'
    config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
    config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
    config.build_settings['SKIP_INSTALL'] = 'YES'
    config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
  end
  app.add_dependency(target)
  phase = app.new_copy_files_build_phase('Embed App Extensions')
  phase.dst_subfolder_spec = '14'
  phase.add_file_reference(target.product_reference).settings = {'ATTRIBUTES' => ['RemoveHeadersOnCopy']}
  # Flutter's Thin Binary reads the final app Info.plist. Embed the extension
  # first so Xcode's Info.plist validation cannot create a dependency cycle.
  app.build_phases.delete(phase)
  thin_index = app.build_phases.index { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
  app.build_phases.insert(thin_index || 0, phase)
  project.save
end
